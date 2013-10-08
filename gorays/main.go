package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"github.com/kid0m4n/rays/gorays/vector"
	"log"
	"math"
	"math/rand"
	"os"
	"path"
	"runtime"
	"runtime/pprof"
	"sync"
	"time"
)

type art []string

func readArt() art {
	if *artfile == "ART" {
		*artfile = path.Join(*home, *artfile)
	}
	f, err := os.Open(*artfile)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	a := make(art, 0)
	for scanner.Scan() {
		a = append(a, scanner.Text())
	}

	return a
}

func (a art) objects() []vector.Vector {
	objects := make([]vector.Vector, 0)
	nr := len(a)
	for j := 0; j < nr; j++ {
		nc := len(a[j])
		for k := 0; k < nc; k++ {
			if a[j][k] != ' ' {
				objects = append(objects, vector.Vector{X: float64(k), Y: 6.5, Z: -float64(nr-1-j) - 1.5})
			}
		}
	}

	return objects
}

func rnd(s *uint32) float64 {
	ss := *s
	ss += ss
	ss ^= 1
	if int32(ss) < 0 {
		ss ^= 0x88888eef
	}
	*s = ss
	return float64(*s%95) / float64(95)
}

type image struct {
	size int
	data []byte
}

func newImage(size int) *image {
	return &image{size: size, data: make([]byte, 3*size*size)}
}

func (i *image) Save() {
	f, err := os.Create(*outputfile)
	if err != nil {
		log.Panic(err)
	}
	defer f.Close()

	fmt.Fprintf(f, "P6 %v %v 255 ", i.size, i.size)
	if _, err := f.Write(i.data); err != nil {
		log.Panic(err)
	}
}

type result struct {
	Average float64   `json:"average"`
	Samples []float64 `json:"samples"`
}

func (r result) Save() {
	f, err := os.Create(*resultfile)
	if err != nil {
		log.Panic(err)
	}
	defer f.Close()

	enc := json.NewEncoder(f)
	enc.Encode(r)
}

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

var objects []vector.Vector
var size int

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

	size = int(math.Sqrt(*mp * 1000000))
	log.Printf("Will render %v time(s)", *times)
	if *procs < 1 {
		log.Fatalf("procs (%v) needs to be >= 1", *procs)
	}

	ar := readArt()
	objects = ar.objects()

	var result result
	var overallDuration float64
	img := newImage(size)

	for t := 0; t < *times; t++ {
		log.Printf("Starting render#%v of size %v MP (%vx%v) with %v goroutine(s)", t+1, *mp, size, size, *procs)

		var beforeMemstats runtime.MemStats
		runtime.ReadMemStats(&beforeMemstats)
		startTime := time.Now()

		g := vector.Vector{X: -3.1, Y: -16, Z: 1.9}.Normalize()
		a := vector.Vector{X: 0, Y: 0, Z: 1}.CrossProduct(g).Normalize().Scale(0.002)
		b := g.CrossProduct(a).Normalize().Scale(0.002)
		c := a.Add(b).Scale(-256).Add(g)
		ar := 512 / float64(size)

		rows := make(chan row, size)

		var wg sync.WaitGroup
		wg.Add(*procs)
		for i := 0; i < *procs; i++ {
			go worker(a, b, c, ar, img, rows, &wg)
		}

		for y := (size - 1); y >= 0; y-- {
			rows <- row(y)
		}
		close(rows)
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

	result.Average = overallDuration / float64(*times)
	log.Printf("Average time %v", result.Average)

	result.Save()
	img.Save()
}

type row int

func clamp(v float64) byte {
	if v > 255 {
		return 255
	}
	return byte(v)
}

func (r row) render(a, b, c vector.Vector, ar float64, img *image, seed *uint32) {
	k := (size - int(r) - 1) * 3 * size

	for x := (size - 1); x >= 0; x-- {
		p := vector.Vector{X: 13, Y: 13, Z: 13}

		for i := 0; i < 64; i++ {
			t := a.Scale(rnd(seed) - 0.5).Scale(99).Add(b.Scale(rnd(seed) - 0.5).Scale(99))
			orig := vector.Vector{X: -5, Y: 16, Z: 8}.Add(t)
			dir := t.Scale(-1).Add(a.Scale(rnd(seed) + float64(x)*ar).Add(b.Scale(rnd(seed) + float64(r)*ar)).Add(c).Scale(16)).Normalize()
			p = sampler(orig, dir, seed).Scale(3.5).Add(p)
		}

		img.data[k] = clamp(p.X)
		k++
		img.data[k] = clamp(p.Y)
		k++
		img.data[k] = clamp(p.Z)
		k++
	}
}

func worker(a, b, c vector.Vector, ar float64, img *image, rows <-chan row, wg *sync.WaitGroup) {
	runtime.LockOSThread()
	defer wg.Done()

	seed := rand.Uint32()

	for r := range rows {
		r.render(a, b, c, ar, img, &seed)
	}
}

func sampler(orig, dir vector.Vector, seed *uint32) vector.Vector {
	st, dist, bounce := tracer(orig, dir)
	obounce := bounce

	if st == missUpward {
		p := 1 - dir.Z
		return vector.Vector{X: 1, Y: 1, Z: 1}.Scale(p)
	}

	h := orig.Add(dir.Scale(dist))
	l := vector.Vector{X: 9 + rnd(seed), Y: 9 + rnd(seed), Z: 16}.Add(h.Scale(-1)).Normalize()

	b := l.DotProduct(bounce)

	sf := 1.0
	if b < 0 {
		b = 0
		sf = 0
	} else {
		var st status
		if st, dist, bounce = tracer(h, l); st != missUpward {
			b = 0
			sf = 0
		}
	}

	if st == missDownward {
		h = h.Scale(0.2)
		fc := vector.Vector{X: 3, Y: 3, Z: 3}
		if int(math.Ceil(h.X)+math.Ceil(h.Y))&1 == 1 {
			fc = vector.Vector{X: 3, Y: 1, Z: 1}
		}
		return fc.Scale(b*0.2 + 0.1)
	}

	r := dir.Add(obounce.Scale(obounce.DotProduct(dir.Scale(-2))))

	p := l.DotProduct(r.Scale(sf))
	p33 := p * p    // p ** 2
	p33 = p33 * p33 // p ** 4
	p33 = p33 * p33 // p ** 8
	p33 = p33 * p33 // p ** 16
	p33 = p33 * p33 // p ** 32
	p33 = p33 * p   // p ** 33
	p = p33 * p33 * p33

	return vector.Vector{X: p, Y: p, Z: p}.Add(sampler(h, r, seed).Scale(0.5))
}

type status int

const (
	missUpward = iota
	missDownward
	hit
)

func tracer(orig, dir vector.Vector) (st status, dist float64, bounce vector.Vector) {
	dist = 1e9
	st = missUpward
	p := -orig.Z / dir.Z
	if 0.01 < p {
		dist = p
		bounce = vector.Vector{X: 0, Y: 0, Z: 1}
		st = missDownward
	}

	for i, _ := range objects {
		p := orig.Add(objects[i])
		b := p.DotProduct(dir)
		c := p.DotProduct(p) - 1
		b2 := b * b

		if b2 > c {
			q := b2 - c
			s := -b - math.Sqrt(q)

			if s < dist && s > 0.01 {
				dist = s
				bounce = p // We can lazy compute bounce based on value of p
				st = hit
			}
		}
	}

	if st == hit {
		bounce = bounce.Add(dir.Scale(dist)).Normalize()
	}

	return
}
