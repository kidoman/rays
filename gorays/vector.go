package main

import "math"

type vector struct {
	X, Y, Z float64
}

func (v vector) Add(r vector) vector {
	return vector{v.X + r.X, v.Y + r.Y, v.Z + r.Z}
}

func (v vector) Scale(r float64) vector {
	return vector{v.X * r, v.Y * r, v.Z * r}
}

func (v vector) DotProduct(r vector) float64 {
	return v.X*r.X + v.Y*r.Y + v.Z*r.Z
}

func (v vector) CrossProduct(r vector) vector {
	return vector{v.Y*r.Z - v.Z*r.Y, v.Z*r.X - v.X*r.Z, v.X*r.Y - v.Y*r.X}
}

func (v vector) Normalize() vector {
	factor := 1.0 / math.Sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)
	return vector{v.X * factor, v.Y * factor, v.Z * factor}
}
