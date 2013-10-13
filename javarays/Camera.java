package javarays;

public final class Camera {
    static final RayVector G = (new RayVector(-3.1f, -16.f, 1.9f)).norm();
    static final RayVector UP = (new RayVector(0.f,  0.f,  1.f).cross(G)).norm().scale(.002f);
    static final RayVector RIGHT = (G.cross(UP)).norm().scale(.002f);
    static final RayVector EYE_OFFSET = (UP.add(RIGHT)).scale(-256).add(G);
    static float aspectRatio;

    // Ray Origin
    public static final RayVector ORIGIN   = new RayVector(-5.f, 16.f,  8.f);
}
