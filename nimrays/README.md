# nimrays

## Prerequisites

  * Nimrod

## Usage

    $ nimrod -d:release --threads:on --threadAnalysis:off -t:-ffast-math -t:-funroll-loops -t:-mtune=native -t:-march=native c main.nim
    $ main
    $ open render.ppm
