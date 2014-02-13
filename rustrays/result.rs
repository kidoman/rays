extern mod extra;

use std::io::fs::File;
use extra::json::PrettyEncoder;
use extra::serialize::Encodable;

pub struct Result {
	samples: ~[f64]
}

#[deriving(Encodable)]
struct JsonResult<'a> {
	average: f64,
	samples: &'a[f64]
}

impl Result {
	pub fn sum(&self) -> f64 {
		let mut sum = 0.0;
		for &s in self.samples.iter() {
			sum += s;
		}
		sum
	}

	pub fn average(&self) -> f64 {
		self.sum() / self.samples.len() as f64
	}

	pub fn save(&self, resultfile: &str) {
		match File::create(&Path::new(resultfile)) {
			Some(ref mut file) => {
				let mut enc = PrettyEncoder::new(file);
				JsonResult { average: self.average(), samples: self.samples }.encode(&mut enc);
				file.flush();
			}
			None => {
				println(format!("Opening {} file failed!", resultfile));
			}
		};
	}
}
