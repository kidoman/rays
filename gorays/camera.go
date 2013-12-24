package main

type camera struct {
	dir       vector
	up        vector
	right     vector
	eyeOffset vector

	ar float64
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
