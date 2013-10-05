gorays
===

Go based Raytracer inspired from:

* http://www.cs.utah.edu/~aek/code/card.cpp
* http://fabiensanglard.net/rayTracing_back_of_business_card/index.php

The C++ version (ref/rays.cpp) is optimized and mutli-threaded.

List of all Go optimizations applied: https://kidoman.com/programming/go-getter.html
Second run with C++ optimized: https://kidoman.com/programming/go-getter-part-2.html

How to use
===

Prerequisite
---

* go 1.2rc1 or later
* gcc 4.8.1 or later
* GIMP for opening the rendered images

Go version
---

* go get -u github.com/kid0m4n/gorays
* time gorays > gorays.ppm
* open gorays.ppm

C++ version
---

* c++ -std=c++11 -O3 -Wall -pthread -ffast-math -mtune=native -march=native -o crays c++/main.cpp
* time ./crays > crays.ppm
* open crays.ppm
