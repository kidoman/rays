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

RGB{T}(r::T, g::T, b::T) = RGB(convert(T, r), convert(T, g), convert(T, b))

# implement write function for pixel type (called when writing pixel array to STDOUT)
Base.write(s::IO, pix::RGB) = begin n = 0
                                    n += write(s, pix.r)
                                    n += write(s, pix.g)
                                    n += write(s, pix.b)
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

const art = [
" 1111            1    ",
" 1   11         1 1   ",
" 1     1       1   1  ",
" 1     1      1     1 ",
" 1    11     1       1",
" 11111       111111111",
" 1    1      1       1",
" 1     1     1       1",
" 1      1    1       1",
"                      ",
"1         1    11111  ",
" 1       1    1       ",
"  1     1    1        ",
"   1   1     1        ",
"    1 1       111111  ",
"     1              1 ",
"     1              1 ",
"     1             1  ",
"     1        111111  "]

function make_objects()
    objs = Array(Vec{Float64}, 0)

    nr = length(art)
    for j in 1:nr
        nc = length(art[j])
        for k in 1:nc
            if art[j][k] != ' '
                push!(objs, Vec{Float64}(float(k-1), 6.5, -(nr - j) - 2.0))
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

const CAMERA_VEC  = Vec{Float64}(-5.0, 16.0, 8.0)
const EMPTY_VEC   = Vec{Float64}(0.0, 0.0, 0.0)
const STD_VEC     = Vec{Float64}(0.0, 0.0, 1.0)

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
                bounce = unit(p1 + dir * dist)
                st = HIT
            end
        end
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
    p ^= 33
    
    # st == HIT a sphere was hit. cast a ray bouncing from sphere surface
    return RGB{T}(p, p, p) + sample_world(h, r) * 0.5
end


function render(size::Integer, lr::Integer, ur::Integer)
    
    # camera direction
    cam_dir = unit(Vec{Float64}(-3.1, -16.0, 1.9))

    # camera up vector
    cam_up = unit(cross(STD_VEC, cam_dir)) * 0.002

    # right vector
    cam_right = unit(cross(cam_dir, cam_up)) * 0.002
    c = ((cam_up + cam_right) * -256.0) + cam_dir

    # aspect ratio
    ar = 512.0 / size
    
    pixels = Array(RGB{Uint8}, (ur - lr + 1) * size)

    for y in (lr - 1):(ur - 1)
        for x in 0:(size - 1)
            pix = DEFAULT_COLOR
            # cast 64 rays per pixel (for blur and soft shadows)
            for _ in 1:64
                # a little bit of delta up/down and left/right
                t = (cam_up * (rand() - 0.5) * 99.0) + (cam_right * (rand() - 0.5) * 99.0)
                # set the camera focal point and cast the ray
                # accumulating the color returned in pix
                orig = CAMERA_VEC + t
                dir = ((-1.0 * t) + (cam_up * (rand() + ar * float(x)) +
                                     cam_right * (rand() + ar * float(y)) + c) * 16.0)
                dir = unit(dir)
                pix += (sample_world(orig, unit(dir)) * 3.5)
            end
            idx = (ur - y - 1) * size + (size - x)
            pixels[idx] = clamp_rgb8(pix)
        end
    end
    return pixels
end


function render!(pixels::Vector{RGB{Uint8}}, size::Integer)
    # camera direction
    cam_dir = unit(Vec{Float64}(-3.1, -16.0, 1.9))

    # camera up vector
    cam_up = unit(cross(STD_VEC, cam_dir)) * 0.002

    # right vector
    cam_right = unit(cross(cam_dir, cam_up)) * 0.002
    c = ((cam_up + cam_right) * -256.0) + cam_dir

    # aspect ratio
    ar = 512.0 / size

    for y in 0:(size-1)
        for x in 0:(size-1)
            pix = DEFAULT_COLOR
            # cast 64 rays per pixel (for blur and soft shadows)
            for _ in 1:64
                # a little bit of delta up/down and left/right
                t = (cam_up * (rand() - 0.5) * 99.0) + (cam_right * (rand() - 0.5) * 99.0)
                # set the camera focal point and cast the ray
                # accumulating the color returned in pix
                orig = CAMERA_VEC + t
                dir = ((-1.0 * t) + (cam_up * (rand() + ar * float(x)) +
                                     cam_right * (rand() + ar * float(y)) + c) * 16.0)
                dir = unit(dir)
                pix += (sample_world(orig, unit(dir)) * 3.5)
            end
            idx = (size - y - 1) * size + (size - x)
            pixels[idx] = clamp_rgb8(pix)
        end
    end
end

end
