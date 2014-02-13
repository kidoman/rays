pub unsafe fn rnd(s: *mut u32) -> f64 {
	let mut ss : u32 = *s;
	ss += ss;
	ss ^= 1;

	if (ss as i32) < 0 {
		ss ^= 0x88888eef;
	}
	*s = ss;

	return ((*s%95) as f64) / 95.0;
}

pub fn clamp(v: f64) -> u8 {
	if v > 255.0 {
		return 255u8
	}
	return v as u8;
}
