package rays;
import java.io.BufferedOutputStream;
import java.io.FileOutputStream;
import java.util.Random;
import java.util.Vector;

public final class Raycaster {
	final static class vector {
		public float x,y,z;  // Vector has three float attributes.
		public vector(){ x=y=z=0.f;}                                  //Empty constructor
		public vector(final vector v){x=v.x;y=v.y;z=v.z;}                                  //Empty constructor
		public vector(final float a,final float b,final float c){x=a;y=b;z=c;}            //Constructor
		public vector add(final vector r) {return new vector(x+r.x,y+r.y,z+r.z);} //Vector add
		public vector pow(final vector r) {return new vector(y*r.z-z*r.y,z*r.x-x*r.z,x*r.y-y*r.x);} //Cross-product
		public float  dot(final vector r)  {return x*r.x+y*r.y+z*r.z;}    //Vector dot product
		public vector mul(final float r)  {return new vector(x*r,y*r,z*r);}       //Vector scaling
		public vector norm(){return mul((float)(1.f/Math.sqrt(dot(this))));} // Used later for normalizing the vector
	};

	final static class object {
		public float k,j;
		object(final float x, final float y){k=x;j=y;}
	};

	final static char[][] art = {
		"                   ".toCharArray(),
		"    1111           ".toCharArray(),
		"   1    1          ".toCharArray(),
		"  1           11   ".toCharArray(),
		"  1          1  1  ".toCharArray(),
		"  1     11  1    1 ".toCharArray(),
		"  1      1  1    1 ".toCharArray(),
		"   1     1   1  1  ".toCharArray(),
		"    11111     11   ".toCharArray()
	};

	static Vector<object> objects = new Vector<>(art.length * art[0].length);

	static void F() {
		final int nr = art.length;
		final int nc = art[0].length;
		for (int k = nc - 1; k >= 0; k--) {
			for (int j = nr - 1; j >= 0; j--) {
				if (art[j][nc - 1 - k] != ' ') {
					objects.add(new object(-k, -(nr - 1 - j)));
				}
			}
		}
	}

	/* return of seed? */
	static float R(int seed) {
		seed += seed;
		seed ^= 1;
		if (seed < 0) {
			seed ^= 0x88888eef;
		}
		return (float) (seed % 95) / (float) 95;
	}

	final static class TRes {
		float t;
		vector n;
	}

	//The intersection test for line [o,v].
	// Return 2 if a hit was found (and also return distance t and bouncing ray n).
	// Return 0 if no hit was found but ray goes upward
	// Return 1 if no hit was found but ray goes downward
	static int T(vector o,final vector d, final TRes res) {
		res.t = 1e9f;
		res.n = new vector();
		int m = 0;
		final float p = -o.z / d.z;

		if (.01f < p) {
			res.t = p; res.n = new vector(0, 0, 1); m = 1;
		}

		o = o.add(new vector(0, 3, -4));
		for (final object obj : objects) {
			// There is a sphere but does the ray hits it ?
			final vector p1 = o.add(new vector(obj.k, 0, obj.j));
			final float b = p1.dot(d), c = p1.dot(p1) - 1, b2 = b * b;

			// Does the ray hit the sphere ?
			if (b2 > c) {
				// It does, compute the distance camera-sphere
				final float q = b2 - c, s = (float) (-b - Math.sqrt(q));

				if (s < res.t && s > .01f) {
					res.t = s; res.n = (p1.add(d.mul(res.t))).norm(); m = 2;
				}
			}
		}

		return m;
	}

	// (S)ample the world and return the pixel color for
	// a ray passing by point o (Origin) and d (Direction)
	static vector S(final vector o, final vector d, final Random seed) {
		final TRes res = new TRes();

		// Search for an intersection ray Vs World.
		final int m = T(o, d, res);
		final vector on = new vector(res.n);

		if (m == 0) { // m==0
			// No sphere found and the ray goes upward: Generate a sky color
			float p = 1 - d.z;
			p = p * p;
			p = p * p;
			return new vector(.7f, .6f, 1).mul(p);
		}

		// A sphere was maybe hit.
		vector h = o.add(d.mul(res.t)); // h = intersection coordinate
		final vector l = (new vector(9 + seed.nextFloat(), 9 + seed.nextFloat(), 16).add(h.mul(-1.f))).norm(); // 'l' = direction to light (with random delta for soft-shadows).

		// Calculated the lambertian factor
		float b = l.dot(res.n);

		// Calculate illumination factor (lambertian coefficient > 0 or in shadow)?
		if (b < 0 || T(h, l, res) != 0) {
			b = 0;
		}

		if (m == 1) { // m == 1
			h = h.mul(.2f); // No sphere was hit and the ray was going downward: Generate a floor color
			return ((((int) (Math.ceil(h.x) + Math.ceil(h.y))) & 1) == 1 ? new vector(3, 1, 1) : new vector(3, 3, 3)).mul(b * .2f + .1f);
		}

		final vector r = d.add(on.mul(on.dot(d.mul(-2.f)))); // r = The half-vector

		// Calculate the color 'p' with diffuse and specular component
		float p = l.dot(r.mul(b > 0 ? 1.f : 0.f));
		float p33 = p * p;
		p33 = p33 * p33;
		p33 = p33 * p33;
		p33 = p33 * p33;
		p33 = p33 * p33;
		p33 = p33 * p;
		p = p33 * p33 * p33;

		// m == 2 A sphere was hit. Cast an ray bouncing from the sphere surface.
		return new vector(p, p, p).add(S(h, r, seed).mul(.5f)); // Attenuate color by 50% since it is bouncing (*.5)
	}

	final static class Worker implements Runnable  {

		Random seed;
		final int offset;
		final int jump;

		public Worker(final Random _seed, final int _offset, final int _jump) {
			seed = _seed; offset = _offset; jump = _jump;
		}

		@Override
        public void run() {
            for (int y = offset; y < h; y += jump) { // For each row
                int k = (h - y - 1) * w * 3;

                for (int x = w; x-- > 0;) { // For each pixel in a line
                    // Reuse the vector class to store not XYZ but a RGB pixel
                    // color
                    vector p = new vector(13, 13, 13); // Default pixel color is
                                                       // almost pitch black

                    // Cast 64 rays per pixel (For blur (stochastic sampling)
                    // and soft-shadows.
                    for (int r = 64; r-- > 0;) {
                        // The delta to apply to the origin of the view (For
                        // Depth of View blur).
                        final vector t = a.mul(seed.nextFloat()-.5f).mul(99).add(b.mul(seed.nextFloat()-.5f).mul(99)); // A little bit of delta up/down and left/right

                        // Set the camera focal point vector(17,16,8) and Cast the ray
                        // Accumulate the color returned in the p variable
                        p = S(new vector(17, 16, 8).add(t), // Ray Origin
                                t.mul(-1).add((a.mul(seed.nextFloat() + x).add(b.mul(y + seed.nextFloat())).add(c)).mul(16)).norm() // Ray Direction with random deltas
                                // for stochastic sampling
                                , seed).mul(3.5f).add(p); // +p for color accumulation
                    }

                    bytes[k++] = (byte) p.x;
                    bytes[k++] = (byte) p.y;
                    bytes[k++] = (byte) p.z;
                }
            }
		}
	}

	static int w = 512, h = 512;
	static byte[] bytes;

	// The '!' are for normalizing each vectors with ! operator.
	static final vector g = (new vector(-5.5f, -16, 0)).norm(); // WTF ? See https://news.ycombinator.com/item?id=6425965 for more.

	static final vector a = ((new vector(0, 0, 1)).pow(g)).norm().mul(.002f);
	static final vector b = (g.pow(a)).norm().mul(.002f);
	static final vector c = (a.add(b)).mul(-256).add(g);

	public static void main(final String[] args) throws Exception {
		F();

		int num_threads = Runtime.getRuntime().availableProcessors();

		if(args.length > 0) {
			w = Integer.parseInt(args[0]);
		}

		if(args.length > 1) {
			h = Integer.parseInt(args[1]);
		}

		if(args.length > 2) {
			num_threads = Integer.parseInt(args[2]);
		}

		final BufferedOutputStream stream = new BufferedOutputStream(new FileOutputStream("image.ppm"));
		stream.write("".format("P6 %d %d 255 ", w, h).getBytes());

		bytes = new byte[3*w*h];

		final Vector<Thread> threads = new Vector<>();
        for (int i = 0; i < num_threads; ++i) {
            final Thread thread = new Thread(new Worker(new Random(), i, num_threads));
            thread.start();
            threads.add(thread);
        }

        for(final Thread t : threads) {
            t.join();
        }

        stream.write(bytes);
        stream.flush();
        stream.close();
	}
}
