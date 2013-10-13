package javarays;

import java.io.File;

/**
 * Parse given arguments on cmd line.
 *
 * We don't want introduce new dependencies to the project or a build system
 * like maven etc. so we parse the arguments ourself.
 */
public class ArgumentParser {
    public final float megaPixel;
    public final int renderCount;
    public final int renderThreads;
    public final File outputFile;
    public final File resultFile;
    public final File artFile;

    /** The only way to create a instance should be by parseArguments. */
    private ArgumentParser(final float _megaPixel, final int _renderCount,
                           final int _renderThreads, final File oFile,
                           final File rFile, final File aFile) {
        megaPixel = _megaPixel;
        renderCount = _renderCount;
        renderThreads = _renderThreads;
        outputFile = oFile;
        resultFile = rFile;
        artFile = aFile;
    };

    /** */
    static void printUsage() {
        System.out.println("Usage: java javarays/Raycaster [options]");
        System.out.println("  -mp [1.0]");
        System.out.println("      Size of the image in mega pixel.");
        System.out.println();
        System.out.println("  -t  [1]");
        System.out.println("      Number of times the image is rendered.");
        System.out.println();
        System.out.println("  -p  [#CPUs]");
        System.out.println("      Number of threads to render the image.");
        System.out.println();
        System.out.println("  -o  [render.ppm]");
        System.out.println("      Output file for the renderer.");
        System.out.println();
        System.out.println("  -r  [result.json]");
        System.out.println("      Output file for the result.");
        System.out.println();
        System.out.println("  -a  [ART]");
        System.out.println("      Input file for the raytracer.");
        System.out.println();
        System.out.println("  -h");
        System.out.println("      This help.");
    }

    public static ArgumentParser parseArgument(final String[] args) throws IllegalArgumentException {
        float megaPixel = 1;
        int renderCount = 1;
        int renderThreads = Runtime.getRuntime().availableProcessors();
        File oFile = new File("render.ppm");
        File rFile = new File("result.json");
        File aFile = new File("ART");

        try {
            for(int i = 0; i < args.length; i++) {
                if(args[i].equals("-mp") && (i+1) < args.length) {
                    megaPixel = Float.parseFloat(args[++i]);
                } else if(args[i].equals("-t") && (i+1) < args.length) {
                    renderCount = Integer.parseInt(args[++i]);
                } else if(args[i].equals("-p") && (i+1) < args.length) {
                    renderThreads = Integer.parseInt(args[++i]);
                } else if(args[i].equals("-o") && (i+1) < args.length) {
                    oFile = new File(args[++i]);
                } else if(args[i].equals("-r") && (i+1) < args.length) {
                    rFile = new File(args[++i]);
                } else if(args[i].equals("-a") && (i+1) < args.length) {
                    aFile = new File(args[++i]);
                } else if(args[i].equals("-h")) {
                    printUsage();
                    System.exit(0);
                } else {
                    System.err.println("Unrecognized parameter or not enough arguments: " + args[i]);
                    System.err.println();
                    printUsage();
                    System.exit(1);
                }
            }
        } catch(final NumberFormatException e) {
            System.err.println("Error parsing cmd lines parameter.");
            System.err.println();
            printUsage();
            System.exit(1);
        }

        return new ArgumentParser(megaPixel, renderCount, renderThreads,
                                  oFile, rFile, aFile);
    }
}
