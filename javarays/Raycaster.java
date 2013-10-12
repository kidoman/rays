package javarays;

import java.io.BufferedOutputStream;
import java.io.FileOutputStream;
import java.util.Vector;

public final class Raycaster {

    private final static String[] art = {
        " 11111           1    ",
        " 1    1         1 1   ",
        " 1     1       1   1  ",
        " 1     1      1     1 ",
        " 1    11     1       1",
        " 11111       111111111",
        " 1    1      1       1",
        " 1     1     1       1",
        " 1      1    1       1",
        "                      ",
        "1         1    11111  ",
        " 1       1    1       ",
        "  1     1    1        ",
        "   1   1     1        ",
        "    1 1       111111  ",
        "     1              1 ",
        "     1              1 ",
        "     1             1  ",
        "     1        111111  "
    };

    static int size = 512;
    static byte[] bytes;

    static float aspectRatio;

    private static float megaPixel;
    private static int threadCount;
    private static int renderCount;

    /** */
    static void printUsage() {
        System.out.println("Usage: [mega pixels] [render count] [threads]");
        System.out.println("  mega pixels  [  1.0] Size of the image in mega pixel.");
        System.out.println("  render count [    1] Number of times the image is rendered.");
        System.out.println("  threads      [#CPUs] Number of threads to render the image.");
        System.out.println();
        System.out.println("The result image is stored in render.ppm of the current working directory.");
    }

    /**
     * Parse passed command line arguments.
     *
     * Don't use existing libraries to not create dependencies.
     */
    private static void parseArgs(final String[] args) {
        megaPixel = 1;
        renderCount = 1;
        threadCount = Runtime.getRuntime().availableProcessors();

        try {
            if(args.length > 0) {
                megaPixel = Float.parseFloat(args[0]);
            }

            if(args.length > 1) {
                renderCount = Integer.parseInt(args[1]);
            }

            if(args.length > 2) {
                threadCount = Integer.parseInt(args[2]);
            }
        } catch(final NumberFormatException e) {
            System.err.println("Error parsing cmd lines parameter.");
            System.err.println();
            printUsage();
            System.exit(1);
        }

        size = (int)(Math.sqrt(megaPixel * 1000000));
        aspectRatio = 512.f / size;
    }

    /** Represent exactly one render pass */
    private static void startRenderPass(final RayVector[] objects) throws Exception {
        final Vector<Thread> threads = new Vector<>();
        for (int i = 0; i < threadCount; ++i) {
            final Thread thread = new Thread(new Worker(objects, i, threadCount));
            thread.start();
            threads.add(thread);
        }

        for(final Thread t : threads) {
            t.join();
        }
    }

    public static void main(final String[] args) throws Exception {
        parseArgs(args);
        final RayVector[] objects = Art.createFromStrings(art);
        bytes = new byte[3*size*size];

        long overallDuration= 0;
        for(int i = 0; i < renderCount; i++) {
            System.out.printf("Starting render#%d of size %.2f MP (%dx%d) with %d threads. ",
                    i+1, megaPixel, size, size, threadCount);

            final long startTime = System.currentTimeMillis();
            startRenderPass(objects);
            final long duration = System.currentTimeMillis() - startTime;
            overallDuration += duration;
            System.out.printf("Completed in %d ms%n", duration);
        }

        System.out.printf("Average time for rendering: %d ms%n", (overallDuration / renderCount));

        final BufferedOutputStream stream = new BufferedOutputStream(new FileOutputStream("render.ppm"));
        stream.write("".format("P6 %d %d 255 ", size, size).getBytes());
        stream.write(bytes);
        stream.flush();
    }
}
