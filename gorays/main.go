package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"log"
	"math"
	"net"
	"net/http"
	"net/url"
	"os"
	"path"
	"runtime"
	"runtime/pprof"
	"sync"
	"time"
)

var (
	cpuprofile = flag.String("cpuprofile", "", "write cpu profile to file")
	mp         = flag.Float64("mp", 1.0, "megapixels of the rendered image")
	times      = flag.Int("t", 1, "times to repeat the benchmark")
	procs      = flag.Int("p", runtime.NumCPU(), "number of render goroutines")
	outputfile = flag.String("o", "render.ppm", "output file to write the rendered image to")
	resultfile = flag.String("r", "result.json", "result file to write the benchmark data to")
	artfile    = flag.String("a", "ART", "the art file to use for rendering")
	home       = flag.String("home", os.Getenv("RAYS_HOME"), "RAYS folder")

	bitwrk_master  = flag.Bool("bitwrk-master", false, "Set to 'true' to have the BitWrk network render for you")
	bitwrk_slave   = flag.Bool("bitwrk-slave", false, "Set to 'true' to offer rendering services to the BitWrk network")
	bitwrk_host    = flag.String("bitwrk-host", "localhost", "BitWrk client host")
	bitwrk_port    = flag.Int("bitwrk-port", 8081, "BitWrk client internal port")
	bitwrk_article = flag.String("bitwrk-article", "net.bitwrk/gorays/0", "BitWrk article ID")
)

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU() + 1)
	flag.Parse()

	if *cpuprofile != "" {
		f, err := os.Create(*cpuprofile)
		if err != nil {
			log.Fatal(err)
		}
		pprof.StartCPUProfile(f)
		defer pprof.StopCPUProfile()
	}

	if *bitwrk_master && *bitwrk_slave {
		log.Fatalf("Either be a BitWrk master or slave, not both")
	}

	if *bitwrk_master {
		runMaster()
	} else if *bitwrk_slave {
		runSlave()
	} else {
		runLocally()
	}
}

func runMaster() {
	if *artfile == "ART" {
		*artfile = path.Join(*home, *artfile)
	}
	in, err := os.Open(*artfile)
	if err != nil {
		log.Fatal(err)
	}
	defer in.Close()

	reqReader, reqWriter := io.Pipe()

	go func() {
		if _, err := fmt.Fprintf(reqWriter, "width:%v\nheight:%v\n\n", 1000, 1000); err != nil {
			log.Fatal(err)
		}
		if _, err := io.Copy(reqWriter, in); err != nil {
			log.Fatal(err)
		}
		if err := reqWriter.Close(); err != nil {
			log.Fatal(err)
		}
	}()

	if resp, err := http.Post(fmt.Sprintf("http://%v:%v/buy/%v", *bitwrk_host, *bitwrk_port, *bitwrk_article), "application/x-gorays", reqReader); err != nil {
		log.Fatal(err)
	} else if resp.StatusCode == http.StatusOK {
		out, err := os.Create(*outputfile)
		if err != nil {
			log.Fatal(err)
		}
		defer out.Close()
		if n, err := io.Copy(out, resp.Body); err != nil {
			log.Fatalf("Couldn't write %s: %v", *outputfile, err)
		} else {
			log.Printf("%d bytes successfully written to %#v", n, *outputfile)
		}
	} else {
		log.Fatalf("Got status code %v (%v)", resp.StatusCode, resp.Status)
	}
}

func runSlave() {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Listening on %v", listener.Addr())
	resp, err := http.PostForm(
		fmt.Sprintf("http://%v:%v/registerworker", *bitwrk_host, *bitwrk_port),
		url.Values{
			"id":      {fmt.Sprintf("gorays-%v", os.Getpid())},
			"article": {*bitwrk_article},
			"pushurl": {fmt.Sprintf("http://%v/", listener.Addr())},
		})
	if err != nil {
		log.Fatal(err)
	}
	if resp.StatusCode != http.StatusOK {
		log.Fatalf("Couldn't register worker: status is %v (%v)", resp.StatusCode, resp.Status)
	}
	http.HandleFunc("/", handleRender)
	err = http.Serve(listener, nil)
	if err != nil {
		log.Fatal(err)
	}
}

func handleRender(w http.ResponseWriter, r *http.Request) {
	// Iterate through parts of multipart body, find the one called "art"
	body := bufio.NewReader(r.Body)
	for {
		line, err := body.ReadString('\n')
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if line == "\n" {
			break
		}
		log.Print(line)
	}
	reader := &io.LimitedReader{body, 100000}

	size := 1000
	ar := readArt(reader)
	objects = ar.objects()
	img := newImage(size)
	cam := newCamera(vector{X: -3.1, Y: -16, Z: 1.9}, size)

	wg := &sync.WaitGroup{}
	wg.Add(*procs)
	for i := 0; i < *procs; i++ {
		w := &worker{id: i, size: size, cam: cam, wg: wg, img: img}
		go w.render()
	}
	wg.Wait()

	runtime.GC()
	if err := img.SaveTo(w); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	log.Printf("rendering complete")
}

func runLocally() {
	size := int(math.Sqrt(*mp * 1000000))
	log.Printf("Will render %v time(s)", *times)
	if *procs < 1 {
		log.Fatalf("procs (%v) needs to be >= 1", *procs)
	}

	if *artfile == "ART" {
		*artfile = path.Join(*home, *artfile)
	}
	f, err := os.Open(*artfile)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	ar := readArt(f)
	objects = ar.objects()

	var result result
	var overallDuration float64
	img := newImage(size)

	for t := 0; t < *times; t++ {
		log.Printf("Starting render#%v of size %v MP (%vx%v) with %v goroutine(s)", t+1, *mp, size, size, *procs)

		var beforeMemstats runtime.MemStats
		runtime.ReadMemStats(&beforeMemstats)
		startTime := time.Now()

		cam := newCamera(vector{X: -3.1, Y: -16, Z: 1.9}, size)

		wg := &sync.WaitGroup{}
		wg.Add(*procs)
		for i := 0; i < *procs; i++ {
			w := &worker{id: i, size: size, cam: cam, wg: wg, img: img}
			go w.render()
		}
		wg.Wait()

		stopTime := time.Now()
		var afterMemstats runtime.MemStats
		runtime.ReadMemStats(&afterMemstats)

		duration := stopTime.Sub(startTime).Seconds()
		result.Samples = append(result.Samples, duration)
		overallDuration += duration

		log.Printf("Render complete, mallocs %v, total alloc %v bytes", afterMemstats.Mallocs-beforeMemstats.Mallocs, afterMemstats.TotalAlloc-beforeMemstats.TotalAlloc)
		log.Printf("Time taken for render %v", duration)

		runtime.GC()
	}

	log.Printf("Average time %v", result.Average())

	result.Save()
	img.Save()
}
