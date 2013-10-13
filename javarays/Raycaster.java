package javarays;

import java.util.Vector;

public final class Raycaster {

    private static ArgumentParser parser;

    /** Represent exactly one render pass */
    private static void startRenderPass(final RayImage img, final RayVector[] objects) throws Exception {
        final Vector<Thread> threads = new Vector<>();
        for (int i = 0; i < parser.renderThreads; ++i) {
            final Thread thread = new Thread(new Worker(img, objects, i, parser.renderThreads));
            thread.start();
            threads.add(thread);
        }

        for(final Thread t : threads) {
            t.join();
        }
    }

    public static void main(final String[] args) throws Exception {
        parser = ArgumentParser.parseArgument(args);
        final RayImage image = new RayImage(parser.megaPixel);
        final RayVector[] objects = Art.createFromFile(parser.artFile);
        Camera.aspectRatio = 512.f / image.size;

        long overallDuration= 0;
        for(int i = 0; i < parser.renderCount; i++) {
            System.out.printf("Starting render#%d of size %.2f MP (%dx%d) with %d threads. ",
                    i+1, parser.megaPixel, image.size, image.size, parser.renderThreads);

            final long startTime = System.currentTimeMillis();
            startRenderPass(image, objects);
            final long duration = System.currentTimeMillis() - startTime;
            overallDuration += duration;
            System.out.printf("Completed in %d ms%n", duration);
        }

        System.out.printf("Average time for rendering: %d ms%n", (overallDuration / parser.renderCount));
        image.save(parser.outputFile);
    }
}
