package main

import (
	"flag"
	"fmt"
	"log"
	"math"
	"math/rand"
	"os"
	"runtime/pprof"
)

type vector struct {
	x, y, z float64
}

func (v vector) add(r vector) vector {
	return vector{v.x + r.x, v.y + r.y, v.z + r.z}
}

func (v vector) scale(r float64) vector {
	return vector{v.x * r, v.y * r, v.z * r}
}

func (v vector) dotProduct(r vector) float64 {
	return v.x*r.x + v.y*r.y + v.z*r.z
}

func (v vector) crossProduct(r vector) vector {
	return vector{v.y*r.z - v.z*r.y, v.z*r.x - v.x*r.z, v.x*r.y - v.y*r.x}
}

func (v vector) normalize() vector {
	return v.scale(1.0 / math.Sqrt(v.dotProduct(v)))
}

func newVector(x, y, z float64) vector {
	return vector{x, y, z}
}

var G = []int{247570, 280596, 280600, 249748, 18578, 18577, 231184, 16, 16}

var (
	cpuprofile = flag.String("cpuprofile", "", "write cpu profile to file")
	width      = flag.Int("width", 512, "width of the rendered image")
	height     = flag.Int("height", 512, "height of the rendered image")
)

func main() {
	flag.Parse()

	if *cpuprofile != "" {
		f, err := os.Create(*cpuprofile)
		if err != nil {
			log.Fatal(err)
		}
		pprof.StartCPUProfile(f)
		defer pprof.StopCPUProfile()
	}

	fmt.Printf("P6 %v %v 255 ", *width, *height)

	g := newVector(-6, -16, 0).normalize()
	a := newVector(0, 0, 1).crossProduct(g).normalize().scale(0.002)
	b := g.crossProduct(a).normalize().scale(0.002)
	c := a.add(b).scale(-256).add(g)

	for y := (*height - 1); y >= 0; y-- {
		for x := (*width - 1); x >= 0; x-- {
			p := vector{13, 13, 13}

			for i := 0; i < 64; i++ {
				t := a.scale(rand.Float64() - 0.5).scale(99).add(b.scale(rand.Float64() - 0.5).scale(99))
				orig := newVector(17, 16, 8).add(t)
				dir := t.scale(-1).add(a.scale(rand.Float64() + float64(x)).add(b.scale(float64(y) + rand.Float64())).add(c).scale(16)).normalize()
				p = sampler(orig, dir).scale(3.5).add(p)
			}

			if n, err := os.Stdout.Write([]byte{byte(p.x), byte(p.y), byte(p.z)}); n != 3 || err != nil {
				panic(err)
			}
		}
	}
}

func sampler(orig, dir vector) vector {
	st, dist, bounce := tracer(orig, dir)

	if st == missUpward {
		return newVector(0.7, 0.6, 1).scale(math.Pow(1-dir.z, 4))
	}

	h := orig.add(dir.scale(dist))
	l := newVector(9+rand.Float64(), 9+rand.Float64(), 16).add(h.scale(-1)).normalize()
	r := dir.add(bounce.scale(bounce.dotProduct(dir.scale(-2))))

	b := l.dotProduct(bounce)

	var st1 status
	if b < 0 {
		b = 0
	} else if st1, dist, bounce = tracer(h, l); st1 != missUpward {
		b = 0
	}

	var sf float64
	if b > 0 {
		sf = 1.0
	}

	p := math.Pow(l.dotProduct(r.scale(sf)), 99)

	if st == missDownward {
		h = h.scale(0.2)
		fc := vector{3, 3, 3}
		if int(math.Ceil(h.x)+math.Ceil(h.y))&1 == 1 {
			fc = vector{3, 1, 1}
		}
		return fc.scale(b*0.2 + 0.1)
	}

	return newVector(p, p, p).add(sampler(h, r).scale(0.5))
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
	p := -orig.z / dir.z
	if 0.01 < p {
		dist = p
		bounce = vector{0, 0, 1}
		st = missDownward
	}

	for k := 18; k >= 0; k-- {
		for j := 8; j >= 0; j-- {
			if G[j]&(1<<uint(k)) != 0 {
				p := orig.add(vector{float64(-k), 0, float64(-j - 4)})
				b := p.dotProduct(dir)
				c := p.dotProduct(p) - 1
				q := b*b - c

				if q > 0 {
					s := -b - math.Sqrt(q)

					if s < dist && s > 0.01 {
						dist = s
						bounce = p.add(dir.scale(dist)).normalize()
						st = hit
					}
				}
			}
		}
	}

	return
}
