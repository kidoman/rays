module Rays

#-- Vector Type ---
immutable Vec{T<:Real}
    x :: T
    y :: T
    z :: T
end

# constructor
Vec(v::Vec) = Vec(v.x, v.y, v.z)

# vector add
+{T<:Real}(a::Vec{T}, b::Vec{T}) = Vec{T}(a.x + b.x, a.y + b.y, a.z + b.z)

# vector scaling 
*{T<:Real}(v::Vec{T}, x::T) = Vec{T}(v.x * x, v.y * x, v.z * x)
*{T<:Real}(x::T, v::Vec{T}) = v * x

# vector dot product
Base.dot{T<:Real}(a::Vec{T}, b::Vec{T}) = a.x * b.x + a.y * b.y + a.z * b.z

# vector cross product
Base.cross{T<:Real}(a::Vec{T}, b::Vec{T}) = Vec{T}(a.y * b.z - a.z * b.y,
                                                   a.z * b.x - a.x * b.z,
                                                   a.x * b.y - a.y * b.x)
# unit vector
unit{T<:Real}(a::Vec{T}) = a * (1.0 / sqrt(dot(a, a)))


#-- Pixel Type ---
immutable RGB{T<:Real}
    r :: T
    g :: T
    b :: T
end

# implement write function for pixel type (called when writing pixel array to STDOUT)
Base.write(s::IO, pix::RGB) = begin n = 0
                                    n += write(pix.r)
                                    n += write(pix.g)
                                    n += write(pix.b)
                                    n
                              end
# add rgb pixels
+{T<:Real}(p1::RGB{T}, p2::RGB{T}) = RGB{T}(p1.r + p2.r, p1.g + p2.g, p1.b + p2.b)

# scale rgb pixels
*{T<:Real}(p::RGB{T}, x::T) = RGB{T}(p.r * x, p.g * x, p.b * x)
*{T<:Real}(x::T, p::RGB{T}) = p * x

# clamp pixel values to prevent integer overflow artifacts
clamp_rgb8{T<:Real}(v::T) = v < 0 ? uint8(0) : v > 255 ? uint8(255) : uint8(v) 
clamp_rgb8{T<:Real}(pix::RGB{T}) = RGB{Uint8}(clamp_rgb8(pix.r),
                                              clamp_rgb8(pix.g),
                                              clamp_rgb8(pix.b))
# -- Objects to Render ---                                              

#const julia_art = ["                     ",
#                   "   11111    1        ",
#                   "     1      1        ",
#                   "     1      1 1      ",
#                   "     1 1  1 1    111 ",
#                   "     1 1  1 1 1 1  1 ",
#                   "  1  1 1  1 1 1 1  11",
#                   "  1111 1111 1 1 111 1"]

const rays_art = [
" 1111            1     ",
" 1   11         1 1    ",
" 1     1       1   1   ",
" 1     1      1     1  ",
" 1    11     1       1 ",
" 11111       111111111 ",
" 1    1      1       1 ",
" 1     1     1       1 ",
" 1      1    1       1 ",
"                       ",
"1         1    11111   ",
" 1       1    1        ",
"  1     1    1         ",
"   1   1     1         ",
"    1 1       111111   ",
"     1              1  ",
"     1              1  ",
"     1             1   ",
"     1        111111   "]

const art = rays_art

function make_objects()
    nr = length(art)
    nc = length(art[1])
    objs = Array(Vec{Float64}, 0)
    for k in (nc-1):-1:0
        for j in (nr-1):-1:0
            if art[j+1][nc-k] != ' '
                push!(objs, Vec{Float64}(-float(k), 3.0, -(nr - 1.0 - j) - 4.0))
            end
        end
    end
    return objs
end

const objects = make_objects()

# --- Contants ----
const HIT        = 2
const NOHIT_DOWN = 1
const NOHIT_UP   = 0

const CAMERA_VEC = Vec{Float64}(17.0, 16.0, 8.0)
const EMPTY_VEC  = Vec{Float64}(0.0, 0.0, 0.0)
const STD_VEC    = Vec{Float64}(0.0, 0.0, 1.0)

# RGB values are declared as floats to avoid casting in inner loops
const DEFAULT_COLOR   = RGB{Float64}(13.0, 13.0, 13.0)
const SKY_VEC         = RGB{Float64}(1.0, 1.0, 1.0)
const FLOOR_PATTERN1  = RGB{Float64}(3.0, 1.0, 1.0)
const FLOOR_PATTERN2  = RGB{Float64}(3.0, 3.0, 3.0)


# the intersection test for line [o, v]
# return HIT if a hit was found (and also return distance t and bouncing ray n)
# return NOHIT_UP if no hit was found but ray goes upward
# return NOHIT_DOWN if no hit was found but ray goes downward
function intersect_test{T<:FloatingPoint}(orig::Vec{T}, dir::Vec{T})
    
    dist = 1e9
    st = NOHIT_UP
    p = -orig.z / dir.z
    bounce = EMPTY_VEC
    
    # downward ray
    if (0.01 < p)
        dist = p
        bounce = STD_VEC
        st = NOHIT_DOWN
    end 

    # search for possible object hit
    for obj = objects
        p1 = orig + obj
        b  = dot(p1, dir)
        c  = dot(p1, p1) - 1.0
        b2 = b * b
        # does the ray hit the sphere ? 
        if b2 > c
            # it does, compute the camera -> sphere dist
            q = b2 - c 
            s = -b - sqrt(q)
            if s < dist && s > 0.01
                dist = s
                bounce = p1
                st = HIT
            end
        end
    end

    # we hit an object, calculate the reflected ray vector
    if st == HIT
        bounce = unit(bounce + dir * dist)
    end
    (st, dist, bounce)
end


# sample the world and return the pixel color 
# for a ray passing by point o and d direction
function sample_world{T<:FloatingPoint}(orig::Vec{T}, dir::Vec{T})
    
    # search for an intersection ray vs world 
    st, dist, bounce = intersect_test(orig, dir)
    obounce = bounce

    if st == NOHIT_UP
        # no sphere found and the ray goes upward: generate sky color
        p = 1.0 - dir.z
        #p = p * p 
        #p = p * p 
  	return SKY_VEC * p
    end

    # sphere was maybe hit
    # (intersection coordinate)
    h = orig + dir * dist
    
    # l => dirction of light with random delta for soft shadows
    l = Vec{T}(9.0 + rand(), 9.0 + rand(), 16.0)
    l = unit(l + (-1.0 * h))
    
    # calculate lambertian factor
    b = dot(l, bounce)

    if b < 0.0
        b = 0.0
    else
        st1, _, _ = intersect_test(h, l)
        if st1 != NOHIT_UP
            b = 0.0
        end
    end
    
    # no object hit, return floor pixel value
    if st == NOHIT_DOWN
        h = h * 0.2
        pattern = isodd(int(ceil(h.x) + ceil(h.y))) ? FLOOR_PATTERN1 : FLOOR_PATTERN2
        return pattern * (b * 0.2 + 0.1)
    end

    # half vector
    r = dir + obounce * dot(obounce, dir * -2.0)
    
    # calculate the color p with diffuse and specular component
    p = dot(l, r * (b > 0.0 ? 1.0 : 0.0))
    
    #p ^= 33
    # only slightly faster (~%5) on my computer
    p33 = p * p
    p33 = p33 * p33
    p33 = p33 * p33
    p33 = p33 * p33
    p33 = p33 * p33
    p33 = p33 * p
    p = p33 * p33 * p33 
    
    # st == HIT a sphere was hit. cast a ray bouncing from sphere surface
    return RGB{T}(p, p, p) + sample_world(h, r) * 0.5
end

function main(width::Int64, height::Int64)
    
    @assert width > 64 && height > 64 
    
    # write PPM header
    const header = bytestring("P6 $width $height 255 ")
    write(STDOUT, header)

    # camera direction
    g = unit(Vec{Float64}(-6.75, -16.0, 1.0))
    
    # camera up vector
    a = unit(cross(STD_VEC, g)) * 0.002
    
    # right vector 
    b = unit(cross(g, a)) * 0.002 
    c = ((a + b) * -256.0) + g
    
    # image array
    pixels = Array(RGB{Uint8}, width * height)
    
    for y in 0:(height - 1)
        for x in 0:(width - 1)
            pix = DEFAULT_COLOR
            # cast 64 rays per pixel (for blur and soft shadows)
            for _ in 1:64
                # a little bit of delta up/down and left/right
                t = (a * (rand() - 0.5) * 99.0) + (b * (rand() - 0.5) * 99.0)
                # set the camera focal point and cast the ray
                # accumulating the color returned in pix 
                orig = CAMERA_VEC + t
                dir = ((-1.0 * t) + (a * (rand() + float(x)) + 
                                     b * (rand() + float(y)) + c) * 16.0)
                dir = unit(dir)
                pix += (sample_world(orig, unit(dir)) * 3.5)
            end
            idx = (height - y - 1) * width + (width - x)
            pixels[idx] = clamp_rgb8(pix)
        end
    end
    write(STDOUT, pixels)
end
end

nargs = length(ARGS)
if nargs     == 0 Rays.main(768, 768)
elseif nargs == 1 Rays.main(int(ARGS[1]), int(ARGS[1]))
elseif nargs == 2 Rays.main(int(ARGS[1]), int(ARGS[2]))
elseif nargs == 3 Rays.main(int(ARGS[1]), int(ARGS[2]))
else println("Error: too many arguments")
end
