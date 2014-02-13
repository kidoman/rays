use std::to_str::ToStr;
use std::num::rsqrt;

pub struct Vector {
	x: f64,
	y: f64,
	z: f64
}

impl Vector {
	pub fn add(&self, r: &Vector) -> Vector {
		Vector { x: r.x + self.x, y: r.y + self.y, z: r.z + self.z }
	}

	pub fn scale(&self, r: f64) -> Vector {
		Vector { x: self.x * r, y: self.y * r, z: self.z * r }
	}

	pub fn dotProduct(&self, r: &Vector) -> f64 {
		return self.x*r.x + self.y*r.y + self.z*r.z
	}

	pub fn crossProduct(&self, r: Vector) -> Vector {
		Vector { x: self.y * r.z - self.z * r.y, y: self.z * r.x - self.x * r.z, z: self.x * r.y - self.y * r.x }
	}

	pub fn normalize(&self) -> Vector {
		self.scale(rsqrt(self.x * self.x + self.y * self.y + self.z * self.z))
	}
}

impl ToStr for Vector {
	fn to_str(&self) -> ~str {
		format!("Vector [x={}, y={}, z={}]", self.x, self.y, self.z)
	}
}
