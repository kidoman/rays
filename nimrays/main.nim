import math
import unsigned
import strutils
import os, osproc

# Define a vector class with constructor and operator: 'v'
type 
  TVector  = tuple[x, y, z: float]

proc `+`(this, r: TVector) : TVector =
  # Vector add
  (this.x + r.x, this.y + r.y, this.z + r.z)

proc `*`(this: TVector, r: float) : TVector =
  # Vector scaling
  (this.x * r, this.y * r, this.z * r)

proc `%`(this, r: TVector) : float =
  # Vector dot product
  this.x * r.x + this.y * r.y + this.z * r.z

proc `^`(this, r: TVector) : TVector =
  # Cross-product
  (this.y*r.z - this.z*r.y, this.z*r.x - this.x*r.z, this.x*r.y - this.y*r.x)

proc `!`(this: TVector) : TVector =
  # Used later for normalizing the vector
  this * (1 / sqrt(this % this))


let art = [ 
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
  "     1        111111   "
]

var objects = newSeq[TVector]()


var y = 1.0 - float(len(art))
for line in art:

  var x = 1.0 - float(len(line))
  for c in line:
    if c != ' ':
      objects.add((float(x), 3.0, y - 4.0))
      
    x += 1.0
  y += 1.0


proc rnd(seed: var uint) : float =
  seed = (seed + seed) xor 1

  if int(seed) < 0:
    seed = seed xor uint(0x88888eef)
    
  return float(seed mod 95) / 95.0


proc tracer(o, d: TVector, t: var float, n: var TVector) : int =
  # The intersection test for line [o,v].
  # Return 2 if a hit was found (and also return distance t and bouncing ray n).
  # Return 0 if no hit was found but ray goes upward
  # Return 1 if no hit was found but ray goes downward
  t = 1e9
  result = 0
  var p = -o.z / d.z

  if 0.01 < p:
    t = p; n = (0.0, 0.0, 1.0); result = 1

  for obj in objects:
    # There is a sphere but does the ray hits it ?
    var
      p  = o + obj
      b  = p % d
      c  = p % p - 1
      b2 = b * b

    # Does the ray hit the sphere ?
    if b2 > c:
      # It does, compute the distance camera-sphere
      let
        q = b2 - c
        s = -b - sqrt(q)

      if s < t and s > 0.01:
        # So far this is the minimum distance, save it. And also
        # compute the bouncing ray vector into 'n'
        t=s; n=p; result = 2

  if result == 2:
    n = !(n + d * t)


proc sampler(o, d: TVector, seed: var uint) : TVector =
  # Sample the world and return the pixel color for
  # a ray passing by point o (Origin) and d (Direction)

  var
    t: float
    n: TVector

  # Search for an intersection ray Vs World.
  let
    m = tracer(o, d, t, n)
    on = n

  if m == 0:
    # No sphere found and the ray goes upward: Generate a sky color
    var p = 1 - d.z
    return (1.0, 1.0, 1.0) * p

  # A sphere was maybe hit.
  var 
    h = o + d * t # h = intersection coordinate
    l = !((9 + rnd(seed), 9 + rnd(seed), 16.0) + h * -1) # 'l' = direction to light (with random delta for soft-shadows).
    b = l % n # Calculated the lambertian factor

  # Calculate illumination factor (lambertian coefficient > 0 or in shadow)?
  if b < 0 or tracer(h, l, t, n) > 0:
    b = 0

  if m == 1:
    h = h * 0.2 # No sphere was hit and the ray was going downward: Generate a floor color
    return
      if (int(ceil(h.x) + ceil(h.y)) and 1) == 1: (3.0, 1.0, 1.0) * (b * 0.2 + 0.1)
      else: (3.0, 3.0, 3.0) * (b * 0.2 + 0.1)

  var r = d + on * (on % d * -2) # r = The half-vector

  # Calculate the color 'p' with diffuse and specular component
  var p = l % r * (if b > 0: 1 else: 0)
  var p33 = p * p
  p33 = p33 * p33
  p33 = p33 * p33
  p33 = p33 * p33
  p33 = p33 * p33
  p33 = p33 * p
  p = p33 * p33 * p33

  # m == 2 A sphere was hit. Cast an ray bouncing from the sphere surface.
  return (p, p, p) + sampler(h, r, seed) * 0.5 # Attenuate color by 50% since it is bouncing (* .5)


# The main block. It generates a PPM image to stdout.
# Usage of the program is hence: ./card > erk.ppm
var
  w = 768
  h = 768
  num_threads = countProcessors()

if num_threads == 0:
  # 8 threads is a reasonable assumption if we don't know how many cores there are
  num_threads = 8

let params = paramCount()
if params > 1:
  w = parseInt(paramStr(1))
if params > 2:
  h = parseInt(paramStr(2))
if params > 3:
  num_threads = parseInt(paramStr(3))

write(stdout, "P6 $1 $2 255 " % [$w, $h]) # The PPM Header is issued

# The '!' are for normalizing each vectors with ! operator.
var 
  g = !(-6.75, -16.0, 1.0)          # Camera direction
  a = !((0.0, 0.0, 1.0)^g) * 0.002  # Camera up vector...Seem Z is pointing up :/ WTF !
  b = !(g^a) * 0.002                # The right vector, obtained via traditional cross-product
  c = (a + b) * -256 + g            # WTF ? See https://news.ycombinator.com/item?id=6425965 for more.

let s = 3 * w * h

var bytes = newSeq[int8](s) 

type TWorkerArgs = tuple[seed: uint, offset, jump: int]

proc worker(args: TWorkerArgs) {.thread.} = 
  var 
    seed   = args.seed
    offset = args.offset
    jump   = args.jump

  for y in countup(offset, h - 1, jump): #For each row
    var k = (h - y - 1) * w * 3

    for x in countdown(w - 1, 0): # For each pixel in a line
      # Reuse the vector class to store not XYZ but a RGB pixel color
      var p: TVector = (13.0, 13.0, 13.0) # Default pixel color is almost pitch black

      # Cast 64 rays per pixel (For blur (stochastic sampling) and soft-shadows.
      for r in countdown(64 - 1, 0):
        # The delta to apply to the origin of the view (For Depth of View blur).
        let t = a * (rnd(seed) - 0.5) * 99 + b * (rnd(seed) - 0.5) * 99 # A little bit of delta up/down and left/right

        # Set the camera focal point vector(17,16,8) and Cast the ray
        # Accumulate the color returned in the p variable
        p = sampler(
          (17.0, 16.0, 8.0) + t, # Ray origin
          !(t * -1 + (a * (rnd(seed) + float(x)) +  b * (float(y) + rnd(seed)) + c) * 16), # Ray Direction with random deltas for stochastic sampling
          seed
        ) * 3.5 + p # +p for color accumulation

      bytes[k] = int8(p.x); inc(k)
      bytes[k] = int8(p.y); inc(k)
      bytes[k] = int8(p.z); inc(k)


var threads = newSeq[TThread[TWorkerArgs]](num_threads)

for i in 0 .. num_threads-1:
  createThread(
    threads[i],
    worker, 
    (uint(math.random(high(int))), i, num_threads)
  )
  
joinThreads(threads)

discard writeBytes(stdout, bytes, 0, s)