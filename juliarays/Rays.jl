immutable Vec{T<:Real}
    x :: T
    y :: T
    z :: T

    function Vec(x::T, y::T, z::T)
        new(x, y, z)
    end 
    
    function Vec(v::Vec{T})
        new(v.x, v.y, v.z)
    end

    function Vec()
        new(convert(T,0),
            convert(T,0),
            convert(T,0))
    end
end

# vector add
+{T<:Real}(a::Vec{T}, b::Vec{T}) = Vec{T}(a.x + b.x, a.y + b.y, a.z + b.z)

# vector scaling 
*{T<:Real}(a::Vec{T}, b::T) = Vec{T}(a.x * b, a.y * b, a.z * b)
*{T<:Real}(a::T, b::Vec{T}) = Vec{T}(a * b.x, a * b.y, a * b.z)

# vector dot product
Base.dot{T<:Real}(a::Vec{T}, b::Vec{T}) = a.x * b.x + a.y * b.y + a.z * b.z

# vector cross product
Base.cross{T<:Real}(a::Vec{T}, b::Vec{T}) = Vec{T}(a.y * b.z - a.z * b.y,
                                                   a.z * b.x - a.x * b.z,
                                                   a.x * b.y - a.y * b.x)
# vector norm
Base.norm{T<:Real}(a::Vec{T}) = a * (1.0 / sqrt(dot(a, a)))


const go_art = ["                   ",
                "    1111           ",
                "   1    1          ",
                "  1           11   ",
                "  1          1  1  ",
                "  1     11  1    1 ",
                "  1      1  1    1 ",
                "   1     1   1  1  ",
                "    11111     11   "]

const julia_art = ["                     ",
                   "   11111    1        ",
                   "     1      1        ",
                   "     1      1 1      ",
                   "     1 1  1 1    111 ",
                   "     1 1  1 1 1 1  1 ",
                   "  1  1 1  1 1 1 1  11",
                   "  1111 1111 1 1 111 1"]

const art = julia_art

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

const HIT        = 2
const NOHIT_DOWN = 1
const NOHIT_UP   = 0

const CAMERA_VEC = Vec{Float64}(17.0, 16.0, 8.0)
const DEFAULT_COLOR = Vec{Float64}(13.0, 13.0, 13.0)

const EMPTY_VEC = Vec{Float64}()
const SKY_VEC   = Vec{Float64}(0.7, 0.6, 1.0)
const STD_VEC   = Vec{Float64}(0.0, 0.0, 1.0)
const PATTERN1  = Vec{Float64}(3.0, 1.0, 1.0)
const PATTERN2  = Vec{Float64}(3.0, 3.0, 3.0)

# the intersection test for line [o, v]
# return HIT if a hit was found (and also return distance t and bouncing ray n)
# return NOHIT_UP if no hit was found but ray goes upward
# return NOHIT_DOWN if no hit was found but ray goes downward

function intersect_test{T<:FloatingPoint}(orig::Vec{T}, dir::Vec{T})
    dist = 1e9
    st = NOHIT_UP
    p = -orig.z / dir.z
    
    bounce = EMPTY_VEC
    
    if (0.01 < p)
        dist = p
        bounce = STD_VEC
        st = NOHIT_DOWN
    end 
   
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
    if st == HIT
        bounce = norm(bounce + dir * dist)
    end
    (st, dist, bounce)
end

# sample the world and return the pixel color 
# for a ray passing by point o and d direction

function sample_world{T<:FloatingPoint}(orig::Vec{T}, dir::Vec{T})
    
    # search for an intersection ray vs world 
    st, dist, bounce = intersect_test(orig, dir)
    
    obounce = Vec{Float64}(bounce)

    if st == NOHIT_UP
        # no sphere found and the ray goes upward: generate sky color
        p = 1 - dir.z
        # p ^= 4
        p = p * p 
        p = p * p 
  	return SKY_VEC * p
    end

    # sphere was maybe hit
    # (intersection coordinate)
    h = orig + dir * dist
    
    # l => dirction of light with random delta for soft shadows
    l = Vec{T}(9.0 + rand(), 9.0 + rand(), 16.0)
    l = norm(l + (-1.0 * h))
    
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
    
    if st == NOHIT_DOWN
        h = h * 0.2
        pattern = isodd(int(ceil(h.x) + ceil(h.y))) ? PATTERN1 : PATTERN2
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
    return Vec{T}(p, p, p) + sample_world(h, r) * 0.5
end


function main()
    const width  = 512
    const height = 512
    
    const header = bytestring("P6 $width $height 255 ")
    write(STDOUT, header)

    # camera direction
    const g = norm(Vec{Float64}(-5.5, -16.0, 0.0))
    
    # camera up vector
    const a = norm(cross(STD_VEC, g)) * 0.002
    
    # right vector 
    const b = norm(cross(g, a)) * 0.002 
    const c = (a + b) * -256.0 + g
 
    size = 3 * width * height
    bytes = Array(Uint8, size)
    
    for y in 0:width-1
        for x in 0:height-1
            p = DEFAULT_COLOR
            # cast 64 rays per pixel
            # (for blur (stochastic sampling) and soft shadows)
            for _ in 1:64
                # a little bit of delta up/down and left/right
                t = (a * (rand() - 0.5) * 99.0) + (b * (rand() - 0.5) * 99.0)
                # set the camera focal point (17,16,8) and cast the ray
                # accumulate the color returned in the p variable
                orig = CAMERA_VEC + t
                dir = ((-1.0 * t) + (a * (rand() + float(x)) + 
                                     b * (rand() + float(y)) + c) * 16.0)
                dir = norm(dir)
                p = (sample_world(orig, norm(dir)) * 3.5) + p
            end
            const idx = (height - y - 1) * width * 3 + (width - x - 1) * 3
            bytes[idx + 1] = uint8(p.x) # R
            bytes[idx + 2] = uint8(p.y) # G
            bytes[idx + 3] = uint8(p.z) # B
        end
    end
    write(STDOUT, bytes)
end

main()
