use vector::Vector;

pub struct Camera {
	dir: Vector,
	up: Vector,
	right: Vector,
	eyeOffset: Vector,
	ar: f64
}

impl Camera {
	pub fn new(dir: Vector, size: int) -> Camera {
		let dir = dir.normalize();
		let up = Vector { x: 0.0, y: 0.0, z: 1.0 }.crossProduct(dir).normalize().scale(0.002);
		let right = dir.crossProduct(up).normalize().scale(0.002);
		let eyeOffset = up.add(&right).scale(-256.0).add(&dir);
		let ar = 512.0 / (size as f64);

		Camera { dir: dir, up: up, right: right, eyeOffset: eyeOffset, ar: ar }
	}
}
