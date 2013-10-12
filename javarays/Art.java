package javarays;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.LinkedList;

/**
 * Creates the input for the ray tracer.
 */
public class Art {

    static RayVector[] createFromFile(final File f) throws Exception {
        final LinkedList<String> lines = new LinkedList<>();

        final BufferedReader reader = new BufferedReader(new FileReader(f));
        String line;

        while((line = reader.readLine()) != null) {
            lines.add(line);
        }

        return createFromStrings(lines.toArray(new String[0]));
    }

    static RayVector[] createFromStrings(final String[] art) {
        final LinkedList<RayVector> tmp = new LinkedList<>();

        final int nr = art.length;
        for (int j = 0; j < nr; j++) {
            final char[] artLine = art[j].toCharArray();
            final int nc = artLine.length;
            for (int k = 0; k < nc; k++) {
                if (artLine[k] != ' ') {
                    tmp.add(new RayVector(k, 6.5f, -(nr - j) - 1.0f));
                }
            }
        }

        return tmp.toArray(new RayVector[0]);
    }
}
