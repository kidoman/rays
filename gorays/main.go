package main

import (
	"flag"
	"log"
	"math"
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

	var results results
	var overallDuration float64
	img := newImage(size)

	for t := 0; t < *times; t++ {
		log.Printf("Starting render#%v of size %v MP (%vx%v) with %v goroutine(s)", t+1, *mp, size, size, *procs)

		var beforeMemstats runtime.MemStats
		runtime.ReadMemStats(&beforeMemstats)
		startTime := time.Now()

		cam := newCamera(vector{X: -3.1, Y: -16, Z: 1.9}, size)

		var wg sync.WaitGroup
		wg.Add(*procs)
		for i := 0; i < *procs; i++ {
			w := &worker{id: i, size: size, cam: cam, wg: &wg, img: img}
			go w.render()
		}
		wg.Wait()

		stopTime := time.Now()
		var afterMemstats runtime.MemStats
		runtime.ReadMemStats(&afterMemstats)

		duration := stopTime.Sub(startTime).Seconds()
		results = append(results, duration)
		overallDuration += duration

		log.Printf("Render complete, mallocs %v, total alloc %v bytes", afterMemstats.Mallocs-beforeMemstats.Mallocs, afterMemstats.TotalAlloc-beforeMemstats.TotalAlloc)
		log.Printf("Time taken for render %v", duration)

		runtime.GC()
	}

	log.Printf("Average time %v", results.Average())

	results.Save()
	img.Save()
}
