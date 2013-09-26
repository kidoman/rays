package main

import (
	"flag"
	"fmt"
	"github.com/kid0m4n/gorays/vector"
	"log"
	"math"
	"os"
	"runtime"
	"runtime/pprof"
	"sync"
)

var art = []string{
	"                   ",
	"    1111           ",
	"   1    1          ",
	"  1           11   ",
	"  1          1  1  ",
	"  1     11  1    1 ",
	"  1      1  1    1 ",
	"   1     1   1  1  ",
	"    11111     11   ",
}

var objects = makeObjects()

type object struct {
	k, j int
}

func makeObjects() []object {
	objects := make([]object, 0, len(art)*len(art[0]))
	for k := 18; k >= 0; k-- {
		for j := 8; j >= 0; j-- {
			if string(art[j][18-k]) != " " {
				objects = append(objects, object{k: k, j: 8 - j})
			}
		}
	}

	return objects
}

var seed = ^uint32(0)

func Rand() float64 {
	seed += seed
	seed ^= 1
	if int32(seed) < 0 {
		seed ^= 0x88888eef
	}
	return float64(seed%95) / float64(95)
}

var (
	cpuprofile = flag.String("cpuprofile", "", "write cpu profile to file")
	width      = flag.Int("width", 512, "width of the rendered image")
	height     = flag.Int("height", 512, "height of the rendered image")
	procs      = flag.Int("procs", runtime.NumCPU(), "numbers of parallel renders")
)

func main() {
	runtime.GOMAXPROCS(*procs)
	flag.Parse()

	if *cpuprofile != "" {
		f, err := os.Create(*cpuprofile)
		if err != nil {
			log.Fatal(err)
		}
		pprof.StartCPUProfile(f)
		defer pprof.StopCPUProfile()
	}

	if *procs < 1 {
		log.Fatalf("Procs (%v) needs to be >= 1", *procs)
	}

	fmt.Printf("P6 %v %v 255 ", *width, *height)

	bytes := make([]byte, 3**width**height)

	g := vector.Vector{X: -5.5, Y: -16, Z: 0}.Normalize()
	a := vector.Vector{X: 0, Y: 0, Z: 1}.CrossProduct(g).Normalize().Scale(0.002)
	b := g.CrossProduct(a).Normalize().Scale(0.002)
	c := a.Add(b).Scale(-256).Add(g)

	rows := make(chan row, *height)
	wg := &sync.WaitGroup{}
	for i := 0; i < *procs; i++ {
		wg.Add(1)
		go worker(&a, &b, &c, bytes, rows, wg)
	}

	for y := (*height - 1); y >= 0; y-- {
		rows <- row(y)
	}
	close(rows)
	wg.Wait()

	if _, err := os.Stdout.Write(bytes); err != nil {
		log.Panic(err)
	}
}

type row int

func worker(a, b, c *vector.Vector, bytes []byte, rows <-chan row, wg *sync.WaitGroup) {
	defer wg.Done()
	for r := range rows {
		renderRow(a, b, c, bytes, r)
	}
}

func renderRow(a, b, c *vector.Vector, bytes []byte, r row) {
	k := (*height - int(r) - 1) * 3 * *width

	for x := (*width - 1); x >= 0; x-- {
		p := vector.Vector{X: 13, Y: 13, Z: 13}

		for i := 0; i < 64; i++ {
			t := a.Scale(Rand() - 0.5).Scale(99).Add(b.Scale(Rand() - 0.5).Scale(99))
			orig := vector.Vector{X: 17, Y: 16, Z: 8}.Add(t)
			dir := t.Scale(-1).Add(a.Scale(Rand() + float64(x)).Add(b.Scale(float64(r) + Rand())).Add(*c).Scale(16)).Normalize()
			p = sampler(orig, dir).Scale(3.5).Add(p)
		}

		bytes[k] = byte(p.X)
		bytes[k+1] = byte(p.Y)
		bytes[k+2] = byte(p.Z)

		k += 3
	}
}

func sampler(orig, dir vector.Vector) vector.Vector {
	st, dist, bounce := tracer(orig, dir)

	if st == missUpward {
		p := 1 - dir.Z
		p = p * p
		p = p * p
		return vector.Vector{X: 0.7, Y: 0.6, Z: 1}.Scale(p)
	}

	h := orig.Add(dir.Scale(dist))
	l := vector.Vector{X: 9 + Rand(), Y: 9 + Rand(), Z: 16}.Add(h.Scale(-1)).Normalize()
	r := dir.Add(bounce.Scale(bounce.DotProduct(dir.Scale(-2))))

	b := l.DotProduct(bounce)

	if b < 0 {
		b = 0
	} else {
		var st status
		if st, dist, bounce = tracer(h, l); st != missUpward {
			b = 0
		}
	}

	var sf float64
	if b > 0 {
		sf = 1.0
	}

	if st == missDownward {
		h = h.Scale(0.2)
		fc := vector.Vector{X: 3, Y: 3, Z: 3}
		if int(math.Ceil(h.X)+math.Ceil(h.Y))&1 == 1 {
			fc = vector.Vector{X: 3, Y: 1, Z: 1}
		}
		return fc.Scale(b*0.2 + 0.1)
	}

	p := l.DotProduct(r.Scale(sf))
	p33 := p * p    // p ** 2
	p33 = p33 * p33 // p ** 4
	p33 = p33 * p33 // p ** 8
	p33 = p33 * p33 // p ** 16
	p33 = p33 * p33 // p ** 32
	p33 = p33 * p   // p ** 33
	p = p33 * p33 * p33

	return vector.Vector{X: p, Y: p, Z: p}.Add(sampler(h, r).Scale(0.5))
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

	for _, object := range objects {
		k, j := object.k, object.j

		p := orig.Add(vector.Vector{X: float64(-k), Y: 3, Z: float64(-j - 4)})
		b := p.DotProduct(dir)
		c := p.DotProduct(p) - 1
		q := b*b - c

		if q > 0 {
			s := -b - math.Sqrt(q)

			if s < dist && s > 0.01 {
				dist = s
				bounce = p.Add(dir.Scale(dist)).Normalize()
				st = hit
			}
		}
	}

	return
}
