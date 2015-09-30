#[feature(globs)];
extern mod native;
extern mod extra;

use extra::getopts::*;
use std::os;
use std::path::Path;
use extra::time::precise_time_ns;
use extra::arc::Arc;
use extra::comm::DuplexStream;

use camera::Camera;
use result::Result;
use worker::Worker;
use image::Image;
use vector::Vector;
use art::{Art,readArt};

mod art;
mod image;
mod camera;
mod vector;
mod result;
mod worker;
mod misc;

#[start]
fn start(argc: int, argv: **u8) -> int {
    native::start(argc, argv, main)
}

fn main() {
	 let args = os::args();
	 let opts = ~[
		optflagopt("m"),
		optflagopt("t"),
		optflagopt("p"),
		optflagopt("o"),
		optflagopt("r"),
		optflagopt("a"),
		optflagopt("h")
	];

	let matches = match getopts(args.tail(), opts) {
		Ok(m) => { m }
		Err(f) => { fail!(f.to_err_msg()) }
	};

	let mp = match matches.opt_str("m") {
		Some(s) => { std::num::FromStrRadix::from_str_radix(s, 10).unwrap() }
		None => { 1f32 }
	};

	let size = std::f32::sqrt(mp * 1000000f32) as int;

	let times = match matches.opt_str("t") {
		Some(s) => { std::num::FromStrRadix::from_str_radix(s, 10).unwrap() }
		None => { 1 }
	};
	println(format!("Will render {} time(s)", times));

	let procs = match matches.opt_str("p") {
		Some(s) => { std::num::FromStrRadix::from_str_radix(s, 10).unwrap() }
		None => { std::rt::default_sched_threads() as int }
	};
	if procs < 1 {
		fail!("procs ({}) needs to be >= 1", procs)
	}

	let outputfile = match matches.opt_str("o") {
		Some(s) => { s }
		None => { ~"render.ppm" }
	};

	let resultfile = match matches.opt_str("r") {
		Some(s) => { s }
		None => { ~"result.json" }
	};

	let home = match matches.opt_str("h") {
		Some(s) => { s }
		None => { std::os::getenv("RAYS_HOME").unwrap_or_default() }
	};

	let mut artfile = match matches.opt_str("a") {
		Some(s) => { s }
		None => { ~"ART" }
	};

	if artfile == ~"ART" {
		let path = Path::new(home).join(artfile);
		artfile = path.as_str().unwrap().into_owned();
	}

	let ar : Art = readArt(artfile);
	let objects_arc = Arc::new(ar.objects());

	let mut result = Result { samples: ~[] };
	let image : *mut Image = &mut Image::new(size);

	for t in range(0, times) {
		print(format!("Starting render\\#{0} of size {1} MP ({2}x{3}) with {4} task(s).", t+1, mp, size, size, procs));
		std::io::stdio::flush();
		let startTime = precise_time_ns();

		let cam = Camera::new(Vector { x: -3.1, y: -16.0, z: 1.9 }, size);

		let mut chans = ~[];

		for i in range(0, procs) {
			let (main, worker) = DuplexStream::new();
			worker.send(objects_arc.clone());
			chans.push(worker);

			do spawn {
				let local_arc : Arc<~[Vector]> = main.recv();
				Worker { id: i, cam: cam, image: image, objects: local_arc.get() }.render(procs as uint);
				main.send(());
			}
		}
		chans.iter().advance( |worker| {
			worker.recv();
			true
		});

		let duration = (precise_time_ns() - startTime) as f64 / 1e9;
		result.samples.push(duration);
		println(format!(" Time taken for render {}", duration));
	}

	println(format!("Average time {}", result.average()));
	result.save(resultfile);
	unsafe {
		(*image).save(outputfile);
	}
}