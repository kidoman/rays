use std::vec;
use std::io::fs::File;
use std::path::Path;

pub struct Image {
	size: int,
	data: ~[u8]
}

impl Image {
	pub fn new(size: int) -> Image {
		let cap = (3 * size * size) as uint;
		let mut vec = vec::with_capacity(cap);
		unsafe {
			vec.set_len(cap);
		}
		return Image { size: size, data: vec }
	}

	pub fn save(&self, outputfile: &str) {
		let mut file = File::create(&Path::new(outputfile));
		let s = format!("P6 {} {} 255 ", self.size, self.size);
		file.write(s.as_bytes());
		file.write(self.data);
	}
}
