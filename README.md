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

Go version
---

* go get -u github.com/kid0m4n/gorays
* time gorays > gorays.ppm
* open gorays.ppm (helps to have Gimp installed)

C++ version
---

* c++ -std=c++11 -O3 -Wall -pthread -ffast-math -mtune=native -march=native -o crays c++/main.cpp
* time ./crays > crays.ppm
* open crays.ppm
