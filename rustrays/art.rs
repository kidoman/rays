use vector::Vector;
use std::path::Path;
use std::io::fs::File;
use std::io::buffered::BufferedReader;

pub struct Art(~[~str]);

pub fn readArt(artfile: &str) -> Art {
	let mut lines : ~[~str] = ~[];
	let mut file = BufferedReader::new(File::open(&Path::new(artfile)));
	for line in file.lines() {
		lines.push(line.trim_right().to_owned());
	}
	Art(lines)
}

impl Art {
	pub fn objects(&self) -> ~[Vector] {
		let lines: &~[~str] = match self {
			&Art(ref a) => a
		};

		let mut objects: ~[Vector] = ~[];
		let mut j = 0;
		for ref line in lines.iter() {
			for (k, ref char) in line.char_indices() {
				match *char {
					' ' => { },
					_   => {
								let v = Vector {x: k as f64, y: 6.5, z: -((lines.len()-j) as f64) - 1.0 };
								objects.push(v);
							}
				}
			}
			j += 1;
		}
		objects
	}
}
