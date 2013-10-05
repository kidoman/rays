package vector

import "math"

type Vector struct {
	X, Y, Z float64
}

func (v Vector) Add(r Vector) Vector {
	return Vector{v.X + r.X, v.Y + r.Y, v.Z + r.Z}
}

func (v Vector) Scale(r float64) Vector {
	return Vector{v.X * r, v.Y * r, v.Z * r}
}

func (v Vector) DotProduct(r Vector) float64 {
	return v.X*r.X + v.Y*r.Y + v.Z*r.Z
}

func (v Vector) CrossProduct(r Vector) Vector {
	return Vector{v.Y*r.Z - v.Z*r.Y, v.Z*r.X - v.X*r.Z, v.X*r.Y - v.Y*r.X}
}

func (v Vector) Normalize() Vector {
	factor := 1.0 / math.Sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)
	return Vector{v.X * factor, v.Y * factor, v.Z * factor}
}
