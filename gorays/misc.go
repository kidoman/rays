package main

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

func clamp(v float64) byte {
	if v > 255 {
		return 255
	}
	return byte(v)
}
