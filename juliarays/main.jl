require("Rays")
require("ArgParse")
using ArgParse


function parse_commandline()
    settings = ArgParseSettings()
    @add_arg_table settings begin
        "-m"
            help = "megapixels of the rendered image"
            arg_type = FloatingPoint
            range_tester = x -> x > 0 
            default = 1.0
        "-t"
            help = "times to repeat the benchmark"
            arg_type = Int
            range_tester = x -> x > 0 
            default = 1
        "-o"
            help = "output file of rendered image"
            arg_type = String
            default = "juliarays.ppm"
        "-r"
            help = "output file of benchmark data"
            arg_type = String
            default = "result.json"
        "-a" 
            help = "art file to render"
            arg_type = String
            default = "ART"
        "--home"
            help = "RAYS home folder"
            arg_type = String
            default = "."
        "--profile"
            help = "profile render (-t >= 2)"
            action = :store_true
        "--cprofile"
            help = "profile render including c calls"
            action = :store_true
        end
    parse_args(settings)
end


function object_array(art::Array{Any,1})
    nr = length(art)
    objs = Array(Rays.Vec{Float64}, 0)
    for (j, line) in enumerate(art)
        for (k, c) in enumerate(line)
            if c != ' ' || c != '\n'
                push!(objs, Rays.Vec{Float64}(float(k-1), 6.5, -(nr - j) - 2.0))
            end
        end
    end
    objs
end


function read_art(s::IOStream)
    art = readlines(s)
    object_array(art)
end 


function main()
    parsed_args = parse_commandline()

    homepath   = abspath(parsed_args["home"]) 
    outputfile = parsed_args["o"]
    megapixels = parsed_args["m"]
    artfile    = parsed_args["a"]
    resfile    = parsed_args["r"]
    ntimes     = parsed_args["t"]
    profile    = parsed_args["profile"] || parsed_args["cprofile"]

    if profile && nprocs() > 1
        error("profile is only enabled for single process exec")
    end
    
    if profile && ntimes < 2
        error("profile is only enabled for multiple multiple exec i.e. -t > 1")
    end
    art_object = open(read_art, joinpath(parsed_args["home"], artfile))
    # TODO: we are clobering the size built in
    size = int(sqrt(megapixels * 1e6))
    
    #write PPM header
    fh = open(outputfile, "w")
    header = bytestring("P6 $size $size 255 ")
    write(fh, header)
    
    pixels = Array(Rays.RGB{Uint8}, size^2)
    samples = {}
    overall_time = 0.0
    
    for t in 1:ntimes
 	@printf(
	"Strarting render#%d of size %.2f MP (%dx%d) with %d workers | profile: %s\n",
		t, megapixels, size, size, nworkers(), profile && t > 1)
        Base.gc()
        
        tic()
        if nworkers() == nprocs()
            if profile && t > 1 
               # single process case
	       @profile Rays.render!(pixels, size)
            else
               Rays.render!(pixels, size)
	    end
        else
            # multiprocess case
            remotes = {}
            chunk_idxs = iround(linspace(1, size+1, nworkers()+1))
            # image is raytraced with origin defined as bottom left of image
            for wid in 1:nworkers()
                lr, ur = chunk_idxs[wid], chunk_idxs[wid+1]-1
                ref = remotecall(wid+1, Rays.render, size, lr, ur) 
                push!(remotes, ref)
            end
            # fill in image chunks from workers
            last_idx = size*size
            for (i, r) in enumerate(remotes)
                r = fetch(r)
                l = length(r)
	        pixels[last_idx-l+1:last_idx] = r
                last_idx = last_idx-l
            end
        end 

        runtime = toc()
        overall_time += runtime
        push!(samples, runtime)
	
	@printf("Time taken for render: %.2fs\n", runtime)
    end

    @printf("Average time: %.2fs\n", mean(samples)) 
    # Write Image
    write(fh, pixels)
    close(fh)
     
    # write results file
    samples_str = "[$(join([i < length(samples) ? "$s," : "$s"
    	                    for (i,s) in enumerate(samples)]))]"
    avg_samples = mean(samples)
    fh = open(resfile, "w")
    write(fh,"{average: $avg_samples,\nsamples: $samples_str}")
    close(fh)
    
    # write profile
    if profile
        fh = open("prof.txt", "w")
        Profile.print(fh,C=parsed_args["cprofile"], cols=500)
        close(fh)
    end
end
    
main()
