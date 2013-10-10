package main

import (
	"flag"
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

type camera struct {
	dir       vector
	up        vector
	right     vector
	eyeOffset vector
	ar        float64
}

func newCamera(dir vector, size int) *camera {
	dir = dir.Normalize()
	up := vector{X: 0, Y: 0, Z: 1}.CrossProduct(dir).Normalize().Scale(0.002)
	right := dir.CrossProduct(up).Normalize().Scale(0.002)
	eyeOffset := up.Add(right).Scale(-256).Add(dir)
	ar := 512 / float64(size)

	return &camera{
		dir:       dir,
		up:        up,
		right:     right,
		eyeOffset: eyeOffset,
		ar:        ar,
	}
}

type worker struct {
	id   int
	size int
	cam  *camera
	wg   *sync.WaitGroup
	img  *image
}

func (w *worker) render() {
	runtime.LockOSThread()
	defer w.wg.Done()

	s := rand.Uint32()
	seed := &s

	for y := w.id; y < w.size; y += *procs {
		k := (w.size - y - 1) * 3 * w.size

		for x := (w.size - 1); x >= 0; x-- {
			p := vector{X: 13, Y: 13, Z: 13}

			for i := 0; i < 64; i++ {
				t := w.cam.up.Scale(rnd(seed) - 0.5).Scale(99).Add(w.cam.right.Scale(rnd(seed) - 0.5).Scale(99))
				orig := vector{X: -5, Y: 16, Z: 8}.Add(t)
				dir := t.Scale(-1).Add(w.cam.up.Scale(rnd(seed) + float64(x)*w.cam.ar).Add(w.cam.right.Scale(rnd(seed) + float64(y)*w.cam.ar)).Add(w.cam.eyeOffset).Scale(16)).Normalize()
				p = sampler(orig, dir, seed).Scale(3.5).Add(p)
			}

			w.img.data[k] = clamp(p.X)
			k++
			w.img.data[k] = clamp(p.Y)
			k++
			w.img.data[k] = clamp(p.Z)
			k++
		}
	}
}

func sampler(orig, dir vector, seed *uint32) vector {
	st, dist, bounce := tracer(orig, dir)
	obounce := bounce

	if st == missUpward {
		p := 1 - dir.Z
		return vector{X: 1, Y: 1, Z: 1}.Scale(p)
	}

	h := orig.Add(dir.Scale(dist))
	l := vector{X: 9 + rnd(seed), Y: 9 + rnd(seed), Z: 16}.Add(h.Scale(-1)).Normalize()

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
		fc := vector{X: 3, Y: 3, Z: 3}
		if int(math.Ceil(h.X)+math.Ceil(h.Y))&1 == 1 {
			fc = vector{X: 3, Y: 1, Z: 1}
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

	return vector{X: p, Y: p, Z: p}.Add(sampler(h, r, seed).Scale(0.5))
}

type status int

const (
	missUpward = iota
	missDownward
	hit
)

func tracer(orig, dir vector) (st status, dist float64, bounce vector) {
	dist = 1e9
	st = missUpward
	p := -orig.Z / dir.Z
	if 0.01 < p {
		dist = p
		bounce = vector{X: 0, Y: 0, Z: 1}
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
