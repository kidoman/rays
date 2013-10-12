# julia rays

## Prerequisites

    * julia 0.2.0-prerelease

## Usage
  
    $ julia -p [nprocs] main.jl
    $ open juliarays.ppm

[nprocs] is the total number of process to spawn.
Julia defines "master" and "worker" processes so [nprocs] - 1 workers
are started.  Rendering is divided equally between worker processes, the
master process handles coordination.

For all options:
    
    $ julia main.jl --help

Profiling can be enabled with the --profile switch.
A more detailed profile can be obtained with the --cprofile switch.
Profiling can be enabled when the number of benchmark repeats is > 1.

