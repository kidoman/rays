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
    
    $   julia main.jl --help
        usage: main.jl [-m M] [-t T] [-o O] [-r R] [-a A] [--home HOME]
                     [--profile] [--cprofile] [-h]

	optional arguments:
	  -m M         megapixels of the rendered image (type: FloatingPoint, default: 1.0)
	  -t T         times to repeat the benchmark (type: Int64, default: 1)
	  -o O         output file of rendered image (type: String, default: juliarays.ppm)
	  -r R         output file of benchmark data (type: String, default: result.json)
	  -a A         art file to render (type: String, default: ART)
	  --home HOME  RAYS home folder (type: String, default: ".")
	  --profile    profile render (-t >= 2)
	  --cprofile   output c calls in profile (-t >= 2)
	  -h, --help   show this help message and exit
