package javarays;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;

public final class RayImage {
    byte[] data;
    final int size;

    public RayImage(final float megaPixel) {
        size = (int)(Math.sqrt(megaPixel * 1000000));
        data = new byte[3*size*size];
    }

    public void save(final File outputFile) throws Exception {
        final BufferedOutputStream stream = new BufferedOutputStream(new FileOutputStream(outputFile));
        stream.write(String.format("P6 %d %d 255 ", size, size).getBytes());
        stream.write(data);
        stream.flush();
        stream.close();
    }
}
