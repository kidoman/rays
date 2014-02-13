use std;
use camera::Camera;
use image::Image;
use vector::Vector;
use misc::{rnd, clamp};

pub struct Worker<'a> {
	id: int,
	cam: Camera,
	image: *mut Image,
	objects: &'a~[Vector]
}

impl<'a> Worker<'a> {
	pub fn render(&'a mut self, procs: uint) {
		let mut s = std::rand::random::<u32>();
		let seed = &mut s;

		let (image_data, size) = unsafe {
			(&mut (*self.image).data, (*self.image).size)
		};

		let mut y = self.id;
		while y < size {
			let mut k = (size - y - 1) * 3 * size;
			for x in range(0, size).invert() {
				let mut p = Vector { x: 13.0, y: 13.0, z: 13.0 };
				for _ in range(0, 64) {
					unsafe {
						let t = self.cam.up.scale(rnd(seed) - 0.5)
								.scale(99.0)
								.add(&self.cam.right.scale(rnd(seed) - 0.5).scale(99.0));

						let orig = Vector { x: -5.0, y: 16.0, z: 8.0 }.add(&t);

						let dir = t.scale(-1.0)
								.add(
										&self.cam.up.scale(rnd(seed) + (x as f64)*self.cam.ar)
										.add(&self.cam.right.scale(rnd(seed) + (y as f64)*self.cam.ar))
										.add(&self.cam.eyeOffset).scale(16.0)
									)
								.normalize();
						p = sampler(&orig, &dir, seed, self.objects).scale(3.5).add(&p);
					}
				}

				image_data[k] = clamp(p.x);
				k+=1;

				image_data[k] = clamp(p.y);
				k+=1;

				image_data[k] = clamp(p.z);
				k+=1;
			}
			y += procs as int;
		}
	}
}

fn sampler(orig: &Vector, dir: &Vector, seed: *mut u32, objects: &~[Vector]) -> Vector {
	let (st, dist, bounce) = tracer(orig, dir, objects);
	let obounce = bounce;

	// If we hit the sky, early return!
	match st {
		MissUpward => {
				let p = 1.0 - dir.z;
				return Vector { x: 1.0, y: 1.0, z: 1.0 }.scale(p)
			},
		_ => {}
	}

	// Intersection coordinate.
	let mut h = orig.add(&dir.scale(dist));
	// Director of light (+ random delta for soft shadows.)
	let l = unsafe {
		Vector { x: 9.0 + rnd(seed), y: 9.0 + rnd(seed), z: 16.0 }.add(&h.scale(-1.0)).normalize()
	};

	// Lambertian factor.
	let mut b = l.dotProduct(&bounce);

	let mut sf = 1.0;
	if b < 0.0 {
		b = 0.0;
		sf = 0.0;
	} else {
		//let mut st : Status = MissUpward;
		let (st, _, _) = tracer(&h, &l, objects);
		match st {
			MissUpward => {},
			_ => {
				b = 0.0;
				sf = 0.0;
			}
		}
	}

	// If we hit the ground, early return!
	match st {
		MissDownward => {
			h = h.scale(0.2);
			let mut fc = Vector {x: 3.0, y: 3.0, z: 3.0 };
			if ((h.x.ceil() + h.y.ceil()) as int ) & 1 == 1 {
				fc = Vector { x: 3.0, y: 1.0, z: 1.0 };
			}
			return fc.scale(b*0.2 + 0.1)
		},
		_ => {}
	}

	// Half vector.
	let r = dir.add(&obounce.scale(obounce.dotProduct(&dir.scale(-2.0))));

	// Calculate the color p.
	let p = std::f64::pow(l.dotProduct(&r.scale(sf)), 99.0);

	// Recursively trace the path along, always scaling the next bounce by a factor of 0.5
	Vector { x: p, y: p, z: p }.add(&sampler(&h, &r, seed, objects).scale(0.5))
}

pub enum Status {
	MissUpward,			// Hit the sky?
	MissDownward,		// Hit the ground
	Hit					// Hit an object
}

// Tracer calculates the minimum distance to a intersecting (object, ground, sky) along with the bounce vector
// from the said object.
fn tracer(orig: &Vector, dir: &Vector, objects: &~[Vector]) -> (Status, f64, Vector) {
	// First case (assumption) is that we will hit the sky.
	let mut st = MissUpward;
	let mut dist = 1e9;
	let mut bounce = Vector { x: 0.0, y: 0.0, z: 0.0 };

	// If we are pointing towards the ground:
	let p = -orig.z / dir.z;
	if 0.01 < p {
		st = MissDownward;
		dist = p;
		bounce = Vector { x: 0.0, y: 0.0, z: 1.0 };
	}

	// Iterate through all the objects checking if there is a possible hit.
	for o in objects.iter() {
		// The sphere location is in o
		let p = orig.add(o);
		let b = p.dotProduct(dir);

		let b2 = b * b;
		let c = p.dotProduct(&p) - 1.0;

		if b2 > c {
			let q = b2 - c;
			let s = -b - std::f64::sqrt(q);

			// There is a hit, and it is at a closer distance! So s becomes the new smaller dist.
			if s > 0.01 && s < dist {
				st = Hit;
				dist = s;
				bounce = p.add(&dir.scale(dist)).normalize();
			}
		}
	}

	(st, dist, bounce)
}
