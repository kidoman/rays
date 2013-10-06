# cpprays

## Prerequisites

  * gcc 4.8.1/clang (currently tested with; might work with other compilers)

## Features

  * The `vector` class is optimized with SSE. The optimizations gets activated if `RAYS_CPP_SSE` is defined (see below)

## Usage

    $ **Normal**: c++ -std=c++11 -O3 -Wall -pthread -ffast-math -mtune=native -march=native -funroll-loops -Ofast -o bin/cpprays cpprays/main.cpp
    $ **SSE**: c++ -std=c++11 -O3 -Wall -pthread -ffast-math -mtune=native -march=native -funroll-loops -Ofast -DRAYS_CPP_SSE -o bin/cpprays cpprays/main.cpp
    $ time ./bin/cpprays > cpprays.ppm
    $ open cpprays.ppm
