import math
import unsigned
import strutils
import os, osproc
import times
import json
import sequtils

type TVector = tuple[x, y, z: float]

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
  this * (1.0 / sqrt(this % this))

type TStatus = enum
  MissUpward, MissDownward, Hit

# Read Art from ART file
var
  input: TFile
  path = "ART"

if not (input.open(path, fmRead) or input.open("../" & path, fmRead)):
  raise newException(EIO, "Failed to open ART file")

let art = toSeq(lines(input))
input.close()

# Parse Art into objects
var objects = newSeq[TVector]()

var
  ox = 0.0
  oy = 6.5
  oz = -1.0
  z  = oz - float(len(art))

for line in art:
  var x = ox
  for c in line:
    if c != ' ':
      objects.add((x, oy, z))

    x += 1.0
  z += 1.0

proc rnd(seed: var uint) : float =
  seed = (seed + seed) xor 1

  if int(seed) < 0:
    seed = seed xor uint(0x88888eef)

  return float(seed mod 95) * (1.0 / 95.0)

proc tracer(o, d: TVector, t: var float, n: var TVector) : TStatus =
  # The intersection test for line [o,d].
  t = 1e9
  result = MissUpward
  var p = -o.z / d.z

  if 0.01 < p:
    t = p; n = (0.0, 0.0, 1.0); result = MissDownward

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
        t=s; n = !(p + d * t); result = Hit

proc sampler(o, d: TVector, seed: var uint) : TVector =
  # Sample the world and return the pixel color for
  # a ray passing by point o (Origin) and d (Direction)
  var
    t: float
    n: TVector

  # Search for an intersection ray Vs World.
  let
    m  = tracer(o, d, t, n)
    on = n

  if m == MissUpward:
    # No sphere found and the ray goes upward: Generate a sky color
    var p = 1 - d.z
    return (1.0, 1.0, 1.0) * p

  # A sphere was maybe hit.
  var
    h = o + d * t # h = intersection coordinate
    l = !((9.0 + rnd(seed), 9.0 + rnd(seed), 16.0) + h * -1) # 'l' = direction to light (with random delta for soft-shadows).
    b = l % n # Calculated the lambertian factor

  # Calculate illumination factor (lambertian coefficient > 0 or in shadow)?
  if b < 0 or tracer(h, l, t, n) != MissUpward:
    b = 0

  if m == MissDownward:
    h = h * 0.2 # No sphere was hit and the ray was going downward: Generate a floor color

    return
      if (int(ceil(h.x) + ceil(h.y)) and 1) == 1: (3.0, 1.0, 1.0) * (b * 0.2 + 0.1)
      else: (3.0, 3.0, 3.0) * (b * 0.2 + 0.1)

  var r = d + on * (on % d * -2.0) # r = The half-vector

  # Calculate the color 'p' with diffuse and specular component
  var p = l % r * (if b > 0: 1 else: 0)
  p = pow(p, 99)

  return (p, p, p) + sampler(h, r, seed) * 0.5

template clamp(v: float) : char =
  if v > 255.0: char(255)
  else: char(v)

## Main Entry Point
var
  megaPixels  = 1
  iterations  = 1
  num_threads = countProcessors()

if num_threads == 0:
  num_threads = 8

let params = paramCount()
if params > 0:
  megaPixels = parseInt(paramStr(1))
if params > 1:
  iterations = parseInt(paramStr(2))
if params > 2:
  num_threads = parseInt(paramStr(3))

let imageSize = int(sqrt(float(megaPixels) * 1000.0 * 1000.0))

var
  g     = !(-3.1, -16.0, 1.9)           # Camera direction
  a     = !((0.0, 0.0, 1.0)^g) * 0.002  # Camera up vector
  b     = !(g^a) * 0.002                # The right vector, obtained via traditional cross-product
  c     = (a + b) * -256.0 + g
  ar    = 512.0 / float(imageSize)
  orig0 = (-5.0, 16.0, 8.0)

var bytes = newSeq[char](3 * imageSize * imageSize)

type TWorkerArgs = tuple[seed: uint, offset, jump: int]
proc worker(args: TWorkerArgs) {.thread.} =
  var
    seed   = args.seed
    offset = args.offset
    jump   = args.jump

  for y in countup(offset, imageSize - 1, jump): #For each row
    var k = (imageSize - y - 1) * imageSize * 3

    for x in countdown(imageSize - 1, 0): # For each pixel in a line
      var p: TVector = (13.0, 13.0, 13.0) # Default pixel color is almost pitch black

      # Cast 64 rays per pixel (For blur (stochastic sampling) and soft-shadows.
      for r in countdown(64, 1):

        # The delta to apply to the origin of the view (For Depth of View blur).
        let
          t   = a * (rnd(seed) - 0.5) * 99.0 + b * (rnd(seed) - 0.5) * 99.0
          js  = 16.0
          jt  = -1.0
          ja  = js * (float(x) * ar + rnd(seed))
          jb  = js * (float(y) * ar + rnd(seed))
          dir = !(t*jt + a*ja + b*jb + c*js)

        p = sampler(orig0 + t, dir, seed) * 3.5 + p

      bytes[k] = clamp(p.x); inc(k)
      bytes[k] = clamp(p.y); inc(k)
      bytes[k] = clamp(p.z); inc(k)

var
  samples   = newSeq[float](iterations)
  totalTime = 0.0

echo "Running ", iterations, " iterations"

for t in 0 .. iterations-1:
  echo "Running... ", t+1
  var threads = newSeq[TThread[TWorkerArgs]](num_threads)

  let clockBegin = epochTime()

  for i in 0 .. num_threads-1:
    createThread(
      threads[i],
      worker,
      (uint(math.random(high(int))), i, num_threads)
    )

  joinThreads(threads)

  let timeTaken = epochTime() - clockBegin
  samples[t] = timeTaken
  totalTime += timeTaken

  echo "Time taken ", formatFloat(timeTaken, ffDecimal, precision = 3)

let averageTime = totalTime / float(iterations)
echo "Average time taken ", formatFloat(averageTime, ffDecimal, precision = 3), "s"

# Write out result.json
var result: TFile
if result.open("result.json", fmWrite):
  let res = %{"average": %formatFloat(averageTime, ffDecimal, precision = 3)}
  res["samples"] = newJArray()
  for s in samples:
    res["samples"].add(%formatFloat(s, ffDecimal, precision = 3))
  result.write($res)
  result.close()

# Write out render.ppm
var output: TFile
if output.open("render.ppm", fmWrite):
  write(output, "P6 $1 $1 255 " % [$imageSize]) # The PPM Header is issued
  discard writeChars(output, bytes, 0, len(bytes))
  output.close()
