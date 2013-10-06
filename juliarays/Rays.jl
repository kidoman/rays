immutable Vec{T<:FloatingPoint}
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
        new(0.0, 0.0, 0.0)
    end
end

# vector add
+{T<:FloatingPoint}(a::Vec{T}, b::Vec{T}) = Vec{T}(a.x + b.x, a.y + b.y, a.z + b.z)

# vector scaling 
*{T<:FloatingPoint}(a::Vec{T}, b::T) = Vec{T}(a.x * b, a.y * b, a.z * b)
*{T<:FloatingPoint}(a::T, b::Vec{T}) = Vec{T}(a * b.x, a * b.y, a * b.z)

# vector dot product
Base.dot{T<:FloatingPoint}(a::Vec{T}, b::Vec{T}) = a.x * b.x + a.y * b.y + a.z * b.z

# vector cross product
Base.cross{T<:FloatingPoint}(a::Vec{T}, b::Vec{T}) = Vec{T}(a.y * b.z - a.z * b.y,
                                                            a.z * b.x - a.x * b.z,
                                                            a.x * b.y - a.y * b.x)
# vector norm
Base.norm{T<:FloatingPoint}(a::Vec{T}) = a * (1.0 / sqrt(dot(a, a)))

const art = ["                   ",
             "    1111           ",
             "   1    1          ",
             "  1           11   ",
             "  1          1  1  ",
             "  1     11  1    1 ",
             "  1      1  1    1 ",
             "   1     1   1  1  ",
             "    11111     11   "]

function make_objects()
    nr = length(art)
    nc = length(art[1])
    objs = Array(Vec{Float64}, 0)
    for k in (nc-1):-1:0
        for j in (nr-1):-1:0
            if art[j+1][nc-k] != ' '
                push!(objs, Vec{Float64}(-float(k), 0.0, -(nr - 1.0 - j)))
            end
        end
    end
    return objs
end

function pseudo_random(seed::Uint32)
    seed += seed
    seed ^= 1
    if (int(seed) < 0)
        seed ^= 0x88888eef
    end
    float(seed % 95) / float(95)
    
end

const objects = make_objects()

const SEED = uint32(10)

const HIT        = 2
const NOHIT_DOWN = 1
const NOHIT_UP   = 0

const DEF_COLOR = Vec{Float64}(13.0, 13.0, 13.0)

const EMPTY_VEC = Vec{Float64}()
const TRANS_CONST_VEC = Vec{Float64}(0.0, 3.0, -4.0)

const SKY_VEC   = Vec{Float64}(0.7, 0.6, 1.0)
const STD_VEC   = Vec{Float64}(0.0, 0.0, 1.0)
const PATTERN1  = Vec{Float64}(3.0, 1.0, 1.0)
const PATTERN2  = Vec{Float64}(3.0, 3.0, 3.0)

# the intersection test for line [o, v]
# return 2 if a hit was found (and also return distance t and bouncing ray n)
# return 0 if no hit was found but ray goes upward
# return 1 if no hist was found but ray goes downward

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
   
    orig = orig + TRANS_CONST_VEC
    # adding nothing here gives a 4x speedup???
    last = nothing

    for obj = objects
        p1 = orig + obj
        b = dot(p1, dir)
        c = dot(p1, p1) - 1.0
        b2 = b * b
        # does the ray hit the sphere
        if b2 > c
            # it does, compute the distance camera -> sphere
            q = b2 - c 
            s = -b - sqrt(q)
            if s < dist && s > 0.01
                dist = s
                last = p1
                #bounce = p
                st = HIT
            end
        end
    end
    #if st == HIT
    if last != nothing
        #bounce = norm(bounce + dir * dist)
        bounce = norm(last + (dir * dist))
    end
    #@printf("st: %s, dist: %s, bounce: %s\n", st, dist, bounce)
    (st, dist, bounce)
end

# sample the world and return the pixel color for a ray passing by point o and d direction
function sample_world{T<:FloatingPoint}(orig::Vec{T}, dir::Vec{T}, seed::Uint32)
    # search for an intersection ray vs world 
    st, dist, bounce = intersect_test(orig, dir)
    
    # TODO: is this necessary??
    obounce = Vec{T}(bounce)

    if st == NOHIT_UP
        # no sphere found and the ray goes upward: generate sky color
        p = 1 - dir.z
        p = p * p 
        p = p * p # p ^ 4 
        return SKY_VEC * p
        #@printf("NO_HITUP: %s\n", val)
    end

    # sphere was maybe hit
    # (intersection coordinate)
    h = orig + dir * dist
    
    # l => dirction of light with random delta for soft shadows
    l = Vec{T}(9.0 + pseudo_random(seed), 9.0 + pseudo_random(seed), 16.0)
    l = norm(l + (-1.0 * h))
    
    # calculate lambertian factor
    b = dot(l, bounce)

    # calculate illumination factor
    # lambertian coeff > 0 or in shadow?
    #sf = 1.0 
    #if b < 0.0
    #    b  = 0.0
    #    sf = 0.0
    #else
    #    st, _, _ = intersect_test(h, l)
    #    if st != NOHIT_UP
    #        b  = 0.0
    #        sf = 0.0
    #    end
    #end
    
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
        return ((int(ceil(h.x) + ceil(h.y)) & 1) == 1 ? PATTERN2 : PATTERN2) * (b * 0.2 + 0.1)
    end

    # no sphere was hit and the ray was going downward:
    # generate floor color
    #if st == NOHIT_DOWN
    #    h = h * 0.2
    #    if int(ceil(h.x) + ceil(h.y)) & 1 == 1
    #        pattern = PATTERN1
    #    else
    #        pattern = PATTERN2
    #    end
    #    #pattern = int(ceil(h.x) + ceil(h.y)) & 1 ? PATTERN1 : PATTERN2
    #    val =  pattern * (b * 0.2 + 0.1)
    #    #@printf("NOHIT_DOWN: %s\n",  val)
    #    return val
    #end

    # half vector
    r = dir + obounce * dot(obounce, dir * -2.0)
    
    # calculate the color p with diffuse and specular component
    #p = dot(l, r * sf)
    p = dot(l, r * (b > 0.0 ? 1.0 : 0.0))
    #@printf("p : %s, l: %s, rsf: %s\n", p, l, r*sf)
    p33 = p * p
    p33 = p33 * p33
    p33 = p33 * p33
    p33 = p33 * p33
    p33 = p33 * p33
    p33 = p33 * p
    p = p33 * p33 * p33
    #p = p ^ 33
    # m == 2 a sphere was hit. cast a ray bouncing from sphere surface
    sw = sample_world(h, r, seed) * 0.5
    val = Vec{T}(p, p, p)
    val2 = val + sw
    #@printf("\nHIT: %s\nval: %s\nworld: %s\np: %s\n\n", val2, val,  sw, p)
    return val2
end

const CAMERA_VEC = Vec{Float64}(17.0, 16.0, 8.0)

function main()
    width  = 512
    height = 512
    
    header = bytestring("P6 $width $height 255 ")
    write(STDOUT, header)

    # camera direction
    g = norm(Vec{Float64}(-5.5, -16.0, 0.0))
    
    # camera up vector
    a = norm(cross(STD_VEC, g)) * 0.002
    
    # right vector 
    b = norm(cross(g, a)) * 0.002 
    c = (a + b) * -256.0 + g
 
    size = 3 * width * height
    bytes = Array(Uint8, size)
    
    for y in 1:512
        for x in 1:512
            p = DEF_COLOR
            # cast 64 rays per pixel
            # (for blur (stochastic sampling) and soft shadows)
            for i in 1:64
                # a little bit of delta up/down and left/right
                t = (a * (pseudo_random(SEED) - 0.5) * 99.0) + 
                    (b * (pseudo_random(SEED) - 0.5) * 99.0)
                
                # set the camera focal point (17,16,8) and cast the ray
                # accumulate the color returned in the p variable
                orig = CAMERA_VEC + t
                dir = ((-1.0 * t) + (a * (pseudo_random(SEED) + float(x-1)) + 
                                     b * (pseudo_random(SEED) + float(y-1)) + c) * 16.0)
                dir = norm(dir)
                #println("\n-----------------------------------")
                #@printf("%d: orig: %s\ndir: %s\nnorm %s\np:%s\n",i,  orig, dir, norm(dir), p)
                #println("-----------------------------------\n")
                p = (sample_world(orig, norm(dir), SEED) * 3.5) + p
            end
            # possible bug? cannot assign array element from uint8, due to inexact error
            #@printf("%d, %d, %s\n", x, y, p) 
            #@printf("%f, %f, %f\n", p.x, p.y, p.z)
            pix_r = p.x #< 1.0 ? 0.0 : p.x > 255.0 ? 255.0 : p.x
            pix_g = p.y #< 1.0 ? 0.0 : p.y > 255.0 ? 255.0 : p.y
            pix_b = p.z #< 1.0 ? 0.0 : p.z > 255.0 ? 255.0 : p.z
           
            #@printf("%c%c%c", p.x, p.y, p.z)
            bytes[(y-1) * width * 3 + (x-1) * 3 + 1] = uint8(pix_r)
            bytes[(y-1) * width * 3 + (x-1) * 3 + 2] = uint8(pix_g)
            bytes[(y-1) * width * 3 + (x-1) * 3 + 3] = uint8(pix_b)
        end
    end
    write(STDOUT, bytes)
end

main()
