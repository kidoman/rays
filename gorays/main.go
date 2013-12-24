package main

import (
	"flag"
	"log"
	"math"
	"os"
	"path"
	"runtime"
	"sync"
	"time"
)

var (
	cpuprofile = flag.String("cpuprofile", "", "write cpu profile to file")
	mp         = flag.Float64("mp", 1.0, "megapixels of the rendered image")
	times      = flag.Int("t", 1, "times to repeat the benchmark")
	procs      = flag.Int("p", runtime.NumCPU(), "number of render goroutines")
	outputfile = flag.String("o", "render.ppm", "output file to write the rendered image to")
	resultfile = flag.String("r", "result.json", "result file to write the benchmark data to")
	artfile    = flag.String("a", "ART", "the art file to use for rendering")
	home       = flag.String("home", os.Getenv("RAYS_HOME"), "RAYS folder")
)

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU() + 1)
	flag.Parse()

	// Calculate the dimensions of the image based on the mp flag. Image is always a square.
	size := int(math.Sqrt(*mp * 1000000))
	log.Printf("Will render %v time(s)", *times)
	if *procs < 1 {
		log.Fatalf("procs (%v) needs to be >= 1", *procs)
	}

	// Read the art file.
	if *artfile == "ART" {
		*artfile = path.Join(*home, *artfile)
	}
	f, err := os.Open(*artfile)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	// Create objects out of the art file.
	ar := readArt(f)
	objects = ar.objects()

	var results results
	// Allocate the image.
	img := newImage(size)

	// Run the render *times times.
	for t := 0; t < *times; t++ {
		log.Printf("Starting render#%v of size %v MP (%vx%v) with %v goroutine(s)", t+1, *mp, size, size, *procs)

		// Mark the start time.
		startTime := time.Now()

		// The camera position.
		cam := newCamera(vector{X: -3.1, Y: -16, Z: 1.9}, size)

		var wg sync.WaitGroup
		// Initialize the wait group with *procs tasks, so that wg.Wait() blocks unless
		// wg.Done() is called as many times.
		wg.Add(*procs)
		// Initiate the rendering process across *procs parallel streams.
		for i := 0; i < *procs; i++ {
			w := &worker{id: i, size: size, cam: cam, wg: &wg, img: img}
			go w.render()
		}
		// The following statement blocks until all the goroutines signal back with a wg.Done()
		wg.Wait()

		// Calculate amount of time taken for the render.
		duration := time.Since(startTime).Seconds()
		results = append(results, duration)

		log.Printf("Render complete")
		log.Printf("Time taken for render %v", duration)
	}

	log.Printf("Average time %v", results.Average())

	// Save the results, the image and done.
	results.Save()
	img.Save()
}
