# rays

Tracker: [trello](https://trello.com/b/1CzsFhXj/rays-language-benchmarks)

Ray tracing based language benchmark inspired from:

  * http://www.cs.utah.edu/~aek/code/card.cpp ([expanded](https://gist.github.com/kid0m4n/6680629))
  * http://fabiensanglard.net/rayTracing_back_of_business_card/index.php

## Reference Image

Reference image rendered using the C++ version: [1 Megapixel](https://kidoman.com/images/reference_rays_1m.jpg) (also [2](https://kidoman.com/images/reference_rays_2m.jpg), [3](https://kidoman.com/images/reference_rays_3m.jpg) and [4](https://kidoman.com/images/reference_rays_4m.jpg))

## Why?

I have written two blog posts describing the intent behind this:

  * List of all Go optimizations applied: https://kidoman.com/programming/go-getter.html
  * Second run with C++ optimized: https://kidoman.com/programming/go-getter-part-2.html

[Reddit discussion thread](http://www.reddit.com/r/golang/comments/1nlgbq/business_card_ray_tracer_go_faster_than_c/)

## Why ray tracing?

  * I picked the "Business card raytracer" as it was written in C++ (so a high value fast target) and extremely concise (so I wouldn't be bored to death porting it to Go)
  * The ray tracing algorithm (as implemented) was inherently parallelizable. I wanted to definitely compare and contrast the ease with which I could just take a single threaded solution and have it quickly scale up to multiple cores
  * I was fascinated with the subject of ray tracing since my highschool days. I had coded up a decent raytracer in VB6 (shudder) and even done rudimentary anti-aliasing, etc. The fact that the end result of a benchmark run was a graphic image acted as a self motivator for me

## Why optimize the base algorithm?

Also, *shouldn't we leave it to the compilers to do their best*

Optimizing in a particular language also gives you a feel of "how far" you can push the boundaries of performance when the need arises. Micro optimizations are the root of all evil, no doubt; but not when the subject matter is benchmarking itself (plus, it doesn't hurt that it makes the process fun)

Think of this as a great opportunity to learn the various nuances of these languages, which are otherwise extremely hard to learn/master.

# Different Implementations

Currently, the following versions are currently available, and tracked in their own folders:

  * Go (optimized, multi-threaded)
  * C++ (optimized, multi-threaded, SSE)
  * Java (optimized, multi-threaded)
  * Ruby (multi-threaded)
  * Julia (optimized, single-threaded)

Please feel free to implement the benchmark (refer to the original C++ version [here](https://gist.github.com/kid0m4n/6680629)) in the language of your choice. All optimizations are welcome but try not to stray away too far from the spirit of the original algorithm. The existing implementations can always act as a litmus test.

Also, optimizations to the existing implementation are obviously welcome. I will regularly update the results based on activity/updates to the code.

# How to use

## RAYS_HOME

Set **RAYS_HOME** environment variable to the top level `rays` folder before running any of the benchmarks

## Benchmark Run

The benchmark is to render a 768x768 image with the text:

**R A**<br/>
**Y S**

A program is valid if it outputs a valid PPM image to STDOUT.

## Prerequisite

  * go 1.2rc1 or later
  * gcc 4.8.1 or later
  * Java 7 or later
  * Ruby 2.0.0-p247 / JRuby / Rubinius 2.0
  * Julia 0.2-prerelease
  * GIMP for opening the rendered images

## Implemented benchmarks

We currently have implementations from:

  * go
  * C++ (thanks to Takayuki Matsuoka)
  * Java (thanks to Tobias Kalbitz)
  * Ruby (thanks to Michael Macias)
  * Julia (thanks to Jake Bolewski)
  * Nimrod (thanks to Erik O'Leary)

Please refer to individual README files in the specific folders to find out instructions on how to run the specific benchmark.

# Current Performance

The current performance stacks up like so:

![512x512 image](https://kidoman.com/images/512x512-3.png)
![2048x2048 image](https://kidoman.com/images/2048x2048-3.png)
![4096x4096 image](https://kidoman.com/images/4096x4096-3.png)

# Contributors

The following have contributed to the project one way or the other:

  * [Karan Misra](https://github.com/kid0m4n)
  * Sebastien Binet
  * Robert Melton
  * Nigel Tao
  * kortschak
  * Michael Jones
  * [Takayuki Matsuoka](https://github.com/t-mat)
  * [Tobias Kalbitz](https://github.com/tkalbitz)
  * [Marc Aldorasi](https://github.com/m42a)
  * [Lee Baker](https://github.com/leecbaker)
  * [Michael Macias](https://github.com/zaeleus)
  * [Jake Bolewski](https://github.com/jakebolewski)
  * [Erik O'Leary](https://github.com/onionhammer)

Thanks to everyone for all the help given :)
