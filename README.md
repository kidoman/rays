rays
===

Ray tracing based language benchmark inspired from:

* http://www.cs.utah.edu/~aek/code/card.cpp ([expanded](https://gist.github.com/kid0m4n/6680629))
* http://fabiensanglard.net/rayTracing_back_of_business_card/index.php

Why?
===

I have written two blog posts describing the intent behind this:

* List of all Go optimizations applied: https://kidoman.com/programming/go-getter.html
* Second run with C++ optimized: https://kidoman.com/programming/go-getter-part-2.html

[Reddit discussion thread](http://www.reddit.com/r/golang/comments/1nlgbq/business_card_ray_tracer_go_faster_than_c/)

Why Ray tracing?
===

* I picked the "Business card raytracer" as it was written in C++ (so a high value fast target) and extremely concise (so I wouldn't be bored to death porting it to Go)

* The ray tracing algorithm (as implemented) was inherently parallelizable. I wanted to definitely compare and contrast the ease with which I could just take a single threaded solution and have it quickly scale up to multiple cores

* I was fascinated with the subject of ray tracing since my highschool days. I had coded up a decent raytracer in VB6 (shudder) and even done rudimentary anti-aliasing, etc. The fact that the end result of a benchmark run was a graphic image acted as a self motivator for me

Different Implementations
===

Currently, the following versions are currently available, and tracked in their own folders:

* Go (optimized, multi-threaded)
* C++ (optimized, multi-threaded)

Please feel free to implement the benchmark (refer to the original C++ version [here](https://gist.github.com/kid0m4n/6680629)) in the language of your choice. All optimizations are welcome but try not to stray away too far from the spirit of the original algorithm. The existing implementations can always act as a litmus test.

Also, optimizations to the existing implementation are obviously welcome. I will regularly update the results based on activity/updates to the code.

Why optimize? Shouldn't we leave it to the compilers to do their best
---

Optimizing in a particular language also gives you a feel of "how far" you can go when the need arises. Micro optimizations are the root of all evil, no doubt; but not when the subject matter is benchmarking (plus, it doesn't hurt that it makes the process fun)

How to use
===

Prerequisite
---

* go 1.2rc1 or later
* gcc 4.8.1 or later
* GIMP for opening the rendered images

Go version
---

* go get -u github.com/kid0m4n/rays/gorays
* time gorays > gorays.ppm
* open gorays.ppm

C++ version
---

* git clone git@github.com:kid0m4n/rays.git
* cd rays
* c++ -std=c++11 -O3 -Wall -pthread -ffast-math -mtune=native -march=native -o cpprays cpprays/main.cpp
* time ./cpprays > cpprays.ppm
* open cpprays.ppm

Current Performance
===

The current performance stacks up like so:

![Performance benchmarks](https://kidoman.com/images/go-vs-cpp-after-both-optimized.png)

Contributors
===

The following have contributed to the project one way or the other:

* Sebastien Binet
* Robert Melton
* Nigel Tao
* kortschak
* Michael Jones
* [Takayuki Matsuoka](https://github.com/t-mat)
* [Tobias Kalbitz](https://github.com/tkalbitz)
* [Marc Aldorasi](https://github.com/m42a)

Thanks to everyone for all the help given :)
