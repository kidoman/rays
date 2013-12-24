package main

import "math"

// Vector is a immutable datastructure representating a point in space.
type vector struct {
	X, Y, Z float64
}

// Add adds the passed in vector to the current vector.
func (v vector) Add(r vector) vector {
	return vector{v.X + r.X, v.Y + r.Y, v.Z + r.Z}
}

// Scale scales the vector by the specified amount.
func (v vector) Scale(r float64) vector {
	return vector{v.X * r, v.Y * r, v.Z * r}
}

// DotProduct calculates the dot product between the current vector and the passed in vector.
func (v vector) DotProduct(r vector) float64 {
	return v.X*r.X + v.Y*r.Y + v.Z*r.Z
}

// CrossProduct calculates the cross product between the current vector and the passed in vector.
func (v vector) CrossProduct(r vector) vector {
	return vector{v.Y*r.Z - v.Z*r.Y, v.Z*r.X - v.X*r.Z, v.X*r.Y - v.Y*r.X}
}

// Normalize the current vector.
func (v vector) Normalize() vector {
	factor := 1.0 / math.Sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)
	return vector{v.X * factor, v.Y * factor, v.Z * factor}
}
