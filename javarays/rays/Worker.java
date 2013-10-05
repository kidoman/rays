package rays;

import java.util.concurrent.ThreadLocalRandom;

import rays.Raycaster.vector;

final class Worker implements Runnable  {

    // Default pixel color is almost pitch black
    private final vector DEF_COLOR   = new vector(13, 13, 13);

    private final vector EMPTY_VEC   = new vector();
    private final vector SKY_VEC     = new vector(.7f, .6f, 1);
    private final vector STD_VEC     = new vector( 0,  0,  1);
    private final vector S_CONST_VEC = new vector(17, 16,  8);
    private final vector T_CONST_VEC = new vector( 0,  3, -4);
    private final vector PATTERN1    = new vector( 3,  1,  1);
    private final vector PATTERN2    = new vector( 3,  3,  3);

    // for stochastic sampling
    private final int offset;
    private final int jump;

    private final vector[] objects;

    private float t;
    private vector n;

    public Worker(final vector[] _objects, final int _offset, final int _jump) {
        objects = _objects;
        offset = _offset;
        jump = _jump;
    }

    //The intersection test for line [o,v].
    // Return 2 if a hit was found (and also return distance t and bouncing ray n).
    // Return 0 if no hit was found but ray goes upward
    // Return 1 if no hit was found but ray goes downward
    private final int T(vector o, final vector d) {
        t = 1e9f;
        int m = 0;
        final float p = -o.z / d.z;

        n = EMPTY_VEC;
        if (.01f < p) {
            t = p;
            n = STD_VEC;
            m = 1;
        }

        o = o.add(T_CONST_VEC);
        vector last = null;
        for(int i = 0; i < objects.length; i++) {
            // There is a sphere but does the ray hits it ?
            final vector p1 = o.add(objects[i]);
            final float b = p1.dot(d), c = p1.dot(p1) - 1, b2 = b * b;

            // Does the ray hit the sphere ?
            if (b2 > c) {
                // It does, compute the distance camera-sphere
                final float q = b2 - c, s = (float) (-b - Math.sqrt(q));

                if (s < t && s > .01f) {
                    last = p1;
                    t = s;
                    m = 2;
                }
            }
        }

        if(last != null) {
            n = (last.add(d.mul(t))).norm();
        }

        return m;
    }

    // (S)ample the world and return the pixel color for
    // a ray passing by point o (Origin) and d (Direction)
    private final vector S(final vector o, final vector d) {
        // Search for an intersection ray Vs World.
        final int m = T(o, d);
        final vector on = new vector(n);

        if (m == 0) { // m==0
            // No sphere found and the ray goes upward: Generate a sky color
            float p = 1 - d.z;
            p = p * p;
            p = p * p;
            return SKY_VEC.mul(p);
        }

        // A sphere was maybe hit.
        vector h = o.add(d.mul(t)); // h = intersection coordinate
        final vector l = (new vector(9 + ThreadLocalRandom.current().nextFloat(), 9 + ThreadLocalRandom.current().nextFloat(), 16).add(h.mul(-1.f))).norm(); // 'l' = direction to light (with random delta for soft-shadows).

        // Calculated the lambertian factor
        float b = l.dot(n);

        // Calculate illumination factor (lambertian coefficient > 0 or in shadow)?
        if (b < 0 || T(h, l) != 0) {
            b = 0;
        }

        if (m == 1) { // m == 1
            h = h.mul(.2f); // No sphere was hit and the ray was going downward: Generate a floor color
            return ((((int) (Math.ceil(h.x) + Math.ceil(h.y))) & 1) == 1 ? PATTERN1 : PATTERN2).mul(b * .2f + .1f);
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
        return new vector(p, p, p).add(S(h, r).mul(.5f)); // Attenuate color by 50% since it is bouncing (*.5)
    }

    @Override
    public void run() {
        for (int y = offset; y < Raycaster.h; y += jump) { // For each row
            int k = (Raycaster.h - y - 1) * Raycaster.w * 3;

            for (int x = Raycaster.w; x-- > 0;) { // For each pixel in a line
                // Reuse the vector class to store not XYZ but a RGB pixel
                // color
                final vector p = innerLoop(y, x, DEF_COLOR);
                Raycaster.bytes[k++] = (byte) p.x;
                Raycaster.bytes[k++] = (byte) p.y;
                Raycaster.bytes[k++] = (byte) p.z;
            }
        }
    }

    private vector innerLoop(final int y, final int x, vector p) {
        // Cast 64 rays per pixel (For blur (stochastic sampling)
        // and soft-shadows.
        for (int r = 64; r-- > 0;) {
            // The delta to apply to the origin of the view (For
            // Depth of View blur).
            final vector t = Raycaster.a.mul(ThreadLocalRandom.current().nextFloat()-.5f).mul(99.f).add(Raycaster.b.mul(ThreadLocalRandom.current().nextFloat()-.5f).mul(99.f)); // A little bit of delta up/down and left/right

            // Set the camera focal point vector(17,16,8) and Cast the ray
            // Accumulate the color returned in the p variable
            p = S(S_CONST_VEC.add(t), // Ray Origin
                    t.mul(-1).add((Raycaster.a.mul(ThreadLocalRandom.current().nextFloat() + x).add(Raycaster.b.mul(y + ThreadLocalRandom.current().nextFloat())).add(Raycaster.c)).mul(16.f)).norm() // Ray Direction with random deltas
                    ).mul(3.5f).add(p); // +p for color accumulation
        }
        return p;
    }
}