import core.cpuid;
import core.thread;
import std.process;
import std.datetime;
import std.algorithm;
import std.exception;
import std.conv, std.stdio;
import std.math, std.traits;
import std.random, std.range;
import std.getopt, std.typecons;

struct vector {
  float x,y,z;  // Vector has three float properties.
  auto opBinary(string op,T)(const T r) pure const nothrow {
     static if (op == "+") return vector(x+r.x,y+r.y,z+r.z);               //Vector add
     else static if (op == "*" && is(T==vector))return x*r.x+y*r.y+z*r.z;  //Vector dot product
     else static if (op == "*" && isNumeric!T)  return vector(x*r,y*r,z*r);//Vector scaling
     else static if (op == "^") return vector(y*r.z-z*r.y,z*r.x-x*r.z,x*r.y-y*r.x);//Cross-product
     else static assert(0, "Operator "~op~" not implemented");
  }
}

vector normlz(vector v) pure nothrow {return v*(1/sqrt(v*v));} // Normalize

alias sphere = vector;
struct ray { vector origin, dir;}
alias pixel = Tuple!(int,int);
alias seed_t = uint;

auto pixelRange(uint h, uint w)
{
  static struct pxRange
  {
    private int h, w, y, x, ey, ex;
    auto opIndex(size_t n) pure const { return tuple((w-1)-cast(int)n%w,(ey+h)-cast(int)(n/w)); }
    auto opSlice(size_t start, size_t end) pure const
    { return pxRange(this[start][1]-this[end][1], w, this[start][1], this[start][0], this[end][1], this[end][0]);}
    @property size_t length() { return max(0,y-ey-1)*w+(x+1)+(w-1-ex);}
    alias opDollar = length;
    @property auto front() { return tuple(x,y); }
    void popFront() { !x? x=w-1,--y:--x; }
    @property auto empty() { return y==ey&&x==ex; }
  }
  return pxRange(h,w,h-1,w-1,-1,w-1);
}

auto parseWorld(T)(T artFile) {
  sphere spheres[];
  string[] art;
  foreach (line; File(artFile).byLine)
    art ~= line.idup;

  immutable ox = 0.0f;
  immutable oy = 6.5f;
  immutable oz = -1.0f;
  auto y = oy;
  auto z = oz - art.length.to!float;
  foreach (line;art)
  { float x = ox;
    foreach (c;line)
    {
      if (c != ' ')
        spheres ~= sphere(x, y, z);
      x += 1.0f;
    }
    z += 1.0f;
  }
  return assumeUnique(spheres);
}

auto rnd(ref uint seed) pure nothrow {
  seed += seed;
  seed ^= 1;
  if (cast(int)seed < 0)
    seed ^= 0x8888_8EEF;
  return (seed % 95) / 95.0f;
}

enum Status {
  kMissUpward,
  kMissDownward,
  kHit
}

struct TracerResult {
  vector n;
  float t;
  Status m;
}

TracerResult tracer(W)(W world, ray r) pure nothrow
{
  auto tr = TracerResult (vector(0.0f, 0.0f, 1.0f), 1e9f, Status.kMissUpward);
  const auto _p = -r.origin.z / r.dir.z;

  if(_p > 0.01f) {
    tr.t = _p;
    tr.n = vector(0.0f, 0.0f, 1.0f);
    tr.m = Status.kMissDownward;
  }

  foreach (obj; world) {
    const auto p = r.origin + obj;
    const auto b = p * r.dir;
    const auto c = p * p - 1.0f;
    const auto b2 = b * b;

    if(b2>c) {
      const auto q = b2 - c;
      const auto s = -b - sqrt(q);

      if(s < tr.t && s > 0.01f) {
        tr.t = s;
        tr.n = (p+r.dir*tr.t).normlz;
        tr.m = Status.kHit;
      }
    }
  }
  return tr;
}

vector sampler(W)(W world, ray _r, ref seed_t seed) nothrow {
  //Search for an intersection ray Vs World.
  const auto tr = tracer(world, _r);

  if(tr.m == Status.kMissUpward) {
    const auto p = 1.0f - _r.dir.z;
    return vector(1.0f, 1.0f, 1.0f) * p;
  }

  const auto on = tr.n;
  auto h = _r.origin + _r.dir*tr.t;
  const auto l = (vector(9.0f+rnd(seed),9.0f+rnd(seed),16.0f)+h*-1).normlz;
  float b = l * tr.n;

  if(b < 0.0f) {
    b = 0.0f;
  } else {
    const auto tr2 = tracer(world, ray(h, l));
    if(tr2.m != Status.kMissUpward) {
      b = 0.0f;
    }
  }

  if(tr.m == Status.kMissDownward) {
    h = h * 0.2f;
    b = b * 0.2f + 0.1f;
    const auto chk = cast(int)(ceil(h.x) + ceil(h.y)) & 1;
    const auto bc  = (0 != chk) ? vector(3.0f, 1.0f, 1.0f) : vector(3.0f, 3.0f, 3.0f);
    return bc * b;
  }

  const auto r = _r.dir+on*(on*_r.dir*-2.0f);               // r = The half-vector
  const auto p = (l * r * (b > 0.0f))^^99;
  return vector(p,p,p)+sampler(world, ray(h,r),seed)*0.5f;
}

auto pixelToRays(pixel px, uint canvasSize, ref seed_t seed) pure nothrow
{
  immutable
    g=normlz(vector(-3.1f, -16.0f, 1.9f)),
    a=normlz(vector(0,0,1)^g)*.002f,
    b=normlz(g^a)*.002f,
    c=(a+b)*-256+g,
    orig0 = vector(-5.0f, 16.0f, 8.0f);
  immutable ar = 512.0f / canvasSize;
  immutable raysPerPixel = 64;

  auto x = px[0];
  auto y = px[1];
  ray rays[raysPerPixel];

  foreach (ref r; rays) {
    const auto t = a*((rnd(seed)-.5f)*99.0f) + b*((rnd(seed)-.5f)*99.0f);

    const auto orig = orig0 + t;
    const auto js = 16.0f;
    const auto jt = -1.0f;
    const auto ja = js * (x * ar + rnd(seed));
    const auto jb = js * (y * ar + rnd(seed));
    const auto jc = js;
    const auto dir = (t*jt + a*ja + b*jb + c*jc).normlz;

    r = ray(orig, dir);
  }

  return rays;
}

auto raysToSamples(W)(ReturnType!pixelToRays rays, W world, ref seed_t seed) nothrow
{
  vector samples[rays.length];
  foreach (i,r; rays)
    samples[i] = sampler(world, r, seed);
  return samples;
}

auto samplesToColor(_S)(_S samples)
{
  return reduce!"a + b*3.5f"(vector(13,13,13), samples);
}

auto clamp(float color)
{
  return cast(ubyte)max(0.0f,min(255.0f,color));
}

auto colorToRGB24(vector color)
{
  ubyte[3] rgb24;
  rgb24[0] = color.x.clamp;
  rgb24[1] = color.y.clamp;
  rgb24[2] = color.z.clamp;
  return rgb24;
}

void worker(W,P)(ubyte[3] result[], uint size, W world, P pixelRange)
{
  seed_t seed = rndGen().front;
  size_t i = 0;
  for (auto rng = pixelRange; !rng.empty; rng.popFront(), ++i)
  {
    auto pixel = rng.front;
    result[i] = pixel.pixelToRays(size,seed).raysToSamples(world,seed).samplesToColor.colorToRGB24;
  }
}

auto bindWorkerArgs(W,P)(ubyte[3] result[], uint size, W world, P pixelRange)
{
  return ()=>worker!(W,P)(result, size, world, pixelRange);
}

void main(string[] args) {
  string outputFile = "render.ppm";
  string resultFile = "result.json";
  string home = getenv("RAYS_HOME");
  string artFile = "ART";
  double megaPixels = 1.0;
  int iterations = 1;
  uint procs = 0;
  alias outlog = stderr;
  try
    getopt(args,
        "mp|s", &megaPixels,
        "iterations|t", &iterations,
        "threads|p", &procs,
        "output|o", &outputFile,
        "result|r", &resultFile,
        "art|a", &artFile,
        "home|h", &home);
  catch (Exception e)
  { stderr.write(
      "--mp=X      [        1.0] Megapixels of the rendered image\n"
      "-t=N        [          1] Times to repeat the benchmark\n"
      "-p=N        [   #Threads] Number of render threads\n"
      "-o=FILE     [render.ppm ] Output file to write the rendered image to\n"
      "-r=FILE     [result.json] Result file to write the benchmark data to\n"
      "-a=FILE     [ART        ] the art file to use for rendering\n"
      "--home=PATH [$RAYS_HOME ] RAYS folder\n");
    return;
  }

  uint s = cast(uint)sqrt(megaPixels*1_000_000);

  if (!procs)
    procs = threadsPerCPU();

  if(artFile == "ART" && !home.empty)
      artFile ~= home ~ "/";

  immutable world = parseWorld(artFile);
  auto pxRange = pixelRange(s,s);
  double timings[];
  ubyte[3] image[];
  image.length = s*s;

  foreach (itn; 0 .. iterations)
  {
    Thread[] threads;

    foreach (thread; 0 .. procs)
    { uint len = s*s;
      uint end = min(len,(thread+1)*len/procs);
      uint start = min(end,thread*len/procs);
      threads ~= new Thread(bindWorkerArgs(image[start .. end],
                                           s, world,
                                           pxRange[start .. end]));
    }

    StopWatch sw;
    sw.start;
    foreach (thread; threads)
      thread.start;
    foreach (i,thread; threads)
      thread.join;
    sw.stop;
    timings ~= sw.peek().nsecs*1e-9;
    outlog.writeln("Time taken for render ", timings.back, "s");
  }

  auto average = timings.reduce!"a+b"/timings.length;
  outlog.writeln("Average time taken ", average, "s");

  auto outFile = File(outputFile,"w");
  outFile.writef("P6 %d %d 255 ", s, s); // PPM Header
  outFile.rawWrite(image);

  auto resFile = File(resultFile,"w");
  resFile.write("{\"average\":", average, ",",
                  "\"samples\":", timings,"}\n");
}
