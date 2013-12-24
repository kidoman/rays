package main

import (
	"math"
	"math/rand"
	"sync"
)

type worker struct {
	id   int
	size int
	cam  *camera
	wg   *sync.WaitGroup
	img  *image
}

func (w *worker) render() {
	// Always signal that this goroutine is done once we are done with all our rows.
	defer w.wg.Done()

	// Seed the random generator
	s := rand.Uint32()
	seed := &s

	// If *procs = 8, we render every other 8th row starting with row w.id.
	for y := w.id; y < w.size; y += *procs {
		k := (w.size - y - 1) * 3 * w.size

		// Loop through all the columns.
		for x := (w.size - 1); x >= 0; x-- {
			// The base color.
			p := vector{X: 13, Y: 13, Z: 13}

			// Cast of 64 rays; for a faux depth of field.
			for i := 0; i < 64; i++ {
				t := w.cam.up.Scale(rnd(seed) - 0.5).Scale(99).Add(w.cam.right.Scale(rnd(seed) - 0.5).Scale(99))
				orig := vector{X: -5, Y: 16, Z: 8}.Add(t)
				dir := t.Scale(-1).Add(w.cam.up.Scale(rnd(seed) + float64(x)*w.cam.ar).Add(w.cam.right.Scale(rnd(seed) + float64(y)*w.cam.ar)).Add(w.cam.eyeOffset).Scale(16)).Normalize()
				p = sampler(orig, dir, seed).Scale(3.5).Add(p)
			}

			// Clamp the values and store them in the image.
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

	// If we hit the sky, early return!
	if st == sMissUpward {
		p := 1 - dir.Z
		return vector{X: 1, Y: 1, Z: 1}.Scale(p)
	}

	// Intersection coordinate.
	h := orig.Add(dir.Scale(dist))
	// Director of light (+ random delta for soft shadows.)
	l := vector{X: 9 + rnd(seed), Y: 9 + rnd(seed), Z: 16}.Add(h.Scale(-1)).Normalize()

	// Lambertian factor.
	b := l.DotProduct(bounce)

	// sf is a hack put in because Go doesn't support ternary operator.
	sf := 1.0
	if b < 0 {
		b, sf = 0, 0
	} else {
		var st status
		if st, dist, bounce = tracer(h, l); st != sMissUpward {
			b, sf = 0, 0
		}
	}

	// If we hit the ground, early return!
	if st == sMissDownward {
		h = h.Scale(0.2)
		fc := vector{X: 3, Y: 3, Z: 3}
		if int(math.Ceil(h.X)+math.Ceil(h.Y))&1 == 1 {
			fc = vector{X: 3, Y: 1, Z: 1}
		}
		return fc.Scale(b*0.2 + 0.1)
	}

	// Half vector.
	r := dir.Add(obounce.Scale(obounce.DotProduct(dir.Scale(-2))))
	// Calculate the color p.
	p := math.Pow(l.DotProduct(r.Scale(sf)), 99)

	// Recursively trace the path along, always scaling the next bounce by a factor of 0.5
	return vector{X: p, Y: p, Z: p}.Add(sampler(h, r, seed).Scale(0.5))
}

type status int

const (
	sMissUpward   = iota // Hit the sky?
	sMissDownward        // Hit the ground
	sHit                 // Hit an object
)

// Tracer calculates the minimum distance to a intersecting (object, ground, sky) along with the bounce vector
// from the said object.
func tracer(orig, dir vector) (st status, dist float64, bounce vector) {
	// First case (assumption) is that we will hit the sky.
	st, dist, bounce = sMissUpward, 1e9, vector{X: 0, Y: 0, Z: 0}

	// If we are pointing towards the ground:
	p := -orig.Z / dir.Z
	if 0.01 < p {
		st, dist, bounce = sMissDownward, p, vector{X: 0, Y: 0, Z: 1}
	}

	// Iterate through all the objects checking if there is a possible hit.
	for i, _ := range objects {
		// The sphere location is in objects[i]
		p := orig.Add(objects[i])
		b := p.DotProduct(dir)

		b2 := b * b
		c := p.DotProduct(p) - 1

		// If b^2 - c > 0
		if b2 > c {
			q := b2 - c
			s := -b - math.Sqrt(q)

			// There is a hit, and it is at a closer distance! So s becomes the new smaller dist.
			if s > 0.01 && s < dist {
				st, dist, bounce = sHit, s, p.Add(dir.Scale(dist)).Normalize()
			}
		}
	}

	return
}
