# drays

## Prerequisites

  * D2 compiler (LDC2 recommended)

## Features

## TODO

  * Add SSE version using core.simd based on cpprays

## Usage

    $ **DMD**: dmd -O -release -inline -noboundscheck drays/main.d -odbin -ofbin/drays
    $ **LDC2 0.11.0 options**: ldc2 -O3 -release -vectorize-loops -vectorize-slp-aggressive drays/main.d -od=bin -of=bin/drays
    $ **LDC2 0.12.0_alpha1 options**: ldc2 -mcpu=native -O3 -release -disable-boundscheck -vectorize-loops -vectorize-slp-aggressive drays/main.d -od=bin -of=bin/drays
    $ time ./bin/drays
    $ open render.ppm
