package javarays;

final class RayVector {
    public final float x, y, z; // Vector has three float attributes.

    public RayVector() {
        x = y = z = 0.f;
    }

    public RayVector(final RayVector v) {
        x = v.x;
        y = v.y;
        z = v.z;
    }

    public RayVector(final float a, final float b, final float c) {
        x = a;
        y = b;
        z = c;
    }

    /** Vector add */
    public RayVector add(final RayVector r) {
        return new RayVector(x + r.x, y + r.y, z + r.z);
    }

    /** Vector dot product */
    public float dot(final RayVector r) {
        return x * r.x + y * r.y + z * r.z;
    }

    /** Vector scaling */
    public RayVector scale(final float r) {
        return new RayVector(x * r, y * r, z * r);
    }

    /** Used later for normalizing the vector */
    public RayVector norm() {
        return scale((float) (1.f / Math.sqrt(dot(this))));
    }

    /** Cross-product */
    public RayVector cross(final RayVector r) {
        return new RayVector(y * r.z - z * r.y, z * r.x - x * r.z, x * r.y - y * r.x);
    }
}