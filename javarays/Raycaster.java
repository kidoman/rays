package javarays;

import java.io.BufferedOutputStream;
import java.util.Vector;

public final class Raycaster {

    private final static char[][] art = {
        " 11111           1     ".toCharArray(),
        " 1    1         1 1    ".toCharArray(),
        " 1     1       1   1   ".toCharArray(),
        " 1     1      1     1  ".toCharArray(),
        " 1    11     1       1 ".toCharArray(),
        " 11111       111111111 ".toCharArray(),
        " 1    1      1       1 ".toCharArray(),
        " 1     1     1       1 ".toCharArray(),
        " 1      1    1       1 ".toCharArray(),
        "                       ".toCharArray(),
        "1         1    11111   ".toCharArray(),
        " 1       1    1        ".toCharArray(),
        "  1     1    1         ".toCharArray(),
        "   1   1     1         ".toCharArray(),
        "    1 1       111111   ".toCharArray(),
        "     1              1  ".toCharArray(),
        "     1              1  ".toCharArray(),
        "     1             1   ".toCharArray(),
        "     1        111111   ".toCharArray()
    };

    static private RayVector[] buildObjects() {
        final Vector<RayVector> tmp = new Vector<>(art.length * art[0].length);

        final int nr = art.length;
        final int nc = art[0].length;
        for (int k = nc - 1; k >= 0; k--) {
            for (int j = nr - 1; j >= 0; j--) {
                if (art[j][nc - 1 - k] != ' ') {
                    tmp.add(new RayVector(-k, 6.5f, -(nr - 1 - j) - 3.5f));
                }
            }
        }

        return tmp.toArray(new RayVector[0]);
    }

    static int size = 512;
    static byte[] bytes;

    static float aspectRatio;

    public static void main(final String[] args) throws Exception {
        final RayVector[] objects = buildObjects();
        int num_threads = Runtime.getRuntime().availableProcessors();

        float megaPixel = 1;
        if(args.length > 0) {
            megaPixel = Float.parseFloat(args[0]);
        }

        if(args.length > 1) {
            num_threads = Integer.parseInt(args[1]);
        }

        size = (int)(Math.sqrt(megaPixel * 1000000));
        aspectRatio = 512.f / size;

        final BufferedOutputStream stream = new BufferedOutputStream(System.out);
        stream.write("".format("P6 %d %d 255 ", size, size).getBytes());

        bytes = new byte[3*size*size];

        final Vector<Thread> threads = new Vector<>();
        for (int i = 0; i < num_threads; ++i) {
            final Thread thread = new Thread(new Worker(objects, i, num_threads));
            thread.start();
            threads.add(thread);
        }

        for(final Thread t : threads) {
            t.join();
        }

        stream.write(bytes);
        stream.flush();
    }
}
