#include <stdlib.h>
#include <math.h>
#include <cstring>
#include <random>
#include <thread>
#include <vector>
#include <string>
#include <sstream>
#include <fstream>
#include <iostream>
#include <chrono>
#include <map>

#if defined(RAYS_CPP_SSE)
#include <smmintrin.h>
#endif

#if defined(RAYS_CPP_SSE)

class vector {
public:
  vector() { }
  vector(__m128 a) { xyzw = a; }
  vector(float a, float b, float c) {
    xyzw = _mm_set_ps(0.0, c, b, a);
  }

  float x() const { float v[4]; _mm_store_ps(v, xyzw); return v[0]; }
  float y() const { float v[4]; _mm_store_ps(v, xyzw); return v[1]; }
  float z() const { float v[4]; _mm_store_ps(v, xyzw); return v[2]; }

  vector operator+(const vector r) const {
    return _mm_add_ps(xyzw, r.xyzw);
  }
  vector operator*(const float r) const {
    return _mm_mul_ps(_mm_set1_ps(r), xyzw);
  }
  float operator%(const vector r) const {
    float ret; _mm_store_ss(&ret, _mm_dp_ps(r.xyzw, xyzw, 0x71));
    return ret;
  }
  vector operator^(vector r) const {
    const __m128 & a = xyzw, & b = r.xyzw;
    return _mm_sub_ps(
      _mm_mul_ps(_mm_shuffle_ps(a, a, _MM_SHUFFLE(3, 0, 2, 1)), _mm_shuffle_ps(b, b, _MM_SHUFFLE(3, 1, 0, 2))),
      _mm_mul_ps(_mm_shuffle_ps(a, a, _MM_SHUFFLE(3, 1, 0, 2)), _mm_shuffle_ps(b, b, _MM_SHUFFLE(3, 0, 2, 1)))
    );
  }
  vector operator!() const {
    return *this*(1.f/sqrtf(*this%*this));
  }

private:
    __m128 xyzw;
};

#else

class vector {
public:
  vector(){}
  vector(float a, float b, float c) { _x=a; _y=b; _z=c; }

  float x() const { return _x; }
  float y() const { return _y; }
  float z() const { return _z; }

  vector operator+(vector r) const {
    return vector(_x+r._x, _y+r._y, _z+r._z);
  }
  vector operator*(float r) const {
    return vector(_x*r, _y*r, _z*r);
  }
  float operator%(vector r) const {
    return _x*r._x + _y*r._y + _z*r._z;
  }
  vector operator^(vector r) const {
    return vector(_y*r._z - _z*r._y, _z*r._x - _x*r._z, _x*r._y-_y*r._x);
  }
  vector operator!() const {
    return *this * (1.f / sqrtf(*this % *this));
  }

private:
  float _x, _y, _z;  // Vector has three float attributes.
};

#endif

typedef std::chrono::high_resolution_clock Clock;
typedef std::chrono::duration<double> ClockSec;
typedef std::vector<vector> Objects;
typedef std::vector<std::string> Art;

struct CommandLine {
  CommandLine(int argc, char* argv[])
    : megaPixels { 1.0 }
    , times { 1 }
    , procs { getMaxThreads() }
    , outputFilename { "render.ppm" }
    , resultFilename { "result.json" }
    , artFilename { "ART" }
    , home { getEnv("RAYS_HOME") }
  {
    typedef const std::string& Arg;
    typedef std::function<void(Arg)> ArgFunc;
    typedef std::map<std::string, ArgFunc> ArgFuncMap;

    const ArgFuncMap optionMap {
      { "-mp"  , [this](Arg v) { megaPixels = std::stof(v); } },
      { "-t"   , [this](Arg v) { times = std::stoi(v); } },
      { "-p"   , [this](Arg v) { procs = std::stoi(v); } },
      { "-o"   , [this](Arg v) { outputFilename = v; } },
      { "-r"   , [this](Arg v) { resultFilename = v; } },
      { "-a"   , [this](Arg v) { artFilename = v; } },
      { "-home", [this](Arg v) { home = v; } }
    };

    const std::string delim = "=";
    for(int i = 1; i < argc; ++i) {
      const auto arg = std::string { argv[i] };
      const auto pos = arg.find(delim);
      if(pos != std::string::npos) {
        const auto a = arg.substr(0, pos);
        const auto v = arg.substr(pos + 1);
        const auto it = optionMap.find(a);
        if(it != optionMap.end() && !v.empty()) {
          it->second(v);
        }
      }
    }
  }

  static std::string usage() {
    return
      "-mp=X      [        1.0] Megapixels of the rendered image\n"
      "-t=N       [          1] Times to repeat the benchmark\n"
      "-p=N       [   #Threads] Number of render threads\n"
      "-o=FILE    [render.ppm ] Output file to write the rendered image to\n"
      "-r=FILE    [result.json] Result file to write the benchmark data to\n"
      "-a=FILE    [ART        ] the art file to use for rendering\n"
      "-home=PATH [$RAYS_HOME ] RAYS folder\n";
  }

  static std::string getEnv(const std::string& env) {
  const auto* s = std::getenv(env.c_str());
    return std::string { s ? s : "" };
  }

  static int getMaxThreads(const int defaultMaxThreads = 8) {
    const auto x = std::thread::hardware_concurrency();
    return x ? x : defaultMaxThreads;
  }

  double megaPixels;
  int times;
  int procs;
  std::string outputFilename;
  std::string resultFilename;
  std::string artFilename;
  std::string home;
};

Art readArt(std::istream& artFile) {
  Art art;
  for(std::string line; std::getline(artFile, line); ) {
    art.push_back(line);
  }
  return art;
}

Objects makeObjects(const Art& art) {
  const float ox = 0.0f;
  const float oy = 6.5f;
  const float oz = -1.0f;

  Objects o;
  const float y = oy;
  auto z = oz - static_cast<float>(art.size());
  for(const auto& line : art) {
    auto x = ox;
    for(const auto& c : line) {
      if(' ' != c) {
        o.emplace_back(x, y, z);
      }
      x += 1.0f;
    }
    z += 1.0f;
  }
  return o;
}

float rnd(unsigned int& seed) {
  seed += seed;
  seed ^= 1;
  if ((int)seed < 0)
    seed ^= 0x88888eef;
  return static_cast<float>(seed % 95) * (1.0f / 95.0f);
}

enum class Status {
  kMissUpward,
  kMissDownward,
  kHit
};

Status tracer(const Objects& objects, vector o, vector d, float& t, vector& n) {
  t=1e9f;
  auto m = Status::kMissUpward;
  const float p=-o.z()/d.z();

  if(.01f < p) {
    t = p;
    n = vector(0.0f, 0.0f, 1.0f);
    m = Status::kMissDownward;
  }

  for (const auto& obj : objects) {
    const vector p = o + obj;
    const float b = p % d,
      c = p%p-1.0f,
      b2 = b * b;

    if(b2>c) {
      const float q=b2-c, s=-b-sqrtf(q);

      if(s < t && s > .01f) {
        t = s;
        n = p;
        m = Status::kHit;
      }
    }
  }

  if (m == Status::kHit)
    n=!(n+d*t);

  return m;
}

vector sampler(const Objects& objects, vector o,vector d, unsigned int& seed) {
  float t;
  vector n;

  //Search for an intersection ray Vs World.
  const auto m = tracer(objects, o, d, t, n);
  const vector on = n;

  if(m == Status::kMissUpward) {
    float p = 1 - d.z();
    return vector(1.f, 1.f, 1.f) * p;
  }

  vector h=o+d*t,
    l=!(vector(9.0f+rnd(seed),9.0f+rnd(seed),16.0f)+h*-1);

  float b=l%n;

  if(b < 0.0f || tracer(objects, h, l, t, n) != Status::kMissUpward)
    b=0.0f;

  if(m == Status::kMissDownward) {
    h=h*.2f;
    return((int)(ceil(h.x())+ceil(h.y()))&1?vector(3.0f,1.0f,1.0f):vector(3.0f,3.0f,3.0f))*(b*.2f+.1f);
  }

  const vector r=d+on*(on%d*-2.0f);               // r = The half-vector

  float p=l%r*(b>0);
  float p33 = p*p;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p;
  p = p33*p33*p33;

  return vector(p,p,p)+sampler(objects, h,r,seed)*.5f;
}

int main(int argc, char **argv) {
  auto& outlog = std::cerr;

  const CommandLine cl(argc, argv);
  std::ifstream artFile(cl.artFilename);
  const auto art = readArt(artFile);
  const auto objects = makeObjects(art);

  const auto overallDurationBegin = Clock::now();

  const auto imageSize = static_cast<int>(sqrt(cl.megaPixels * 1000.0 * 1000.0));
  std::vector<unsigned char> bytes(3 * imageSize * imageSize);
  const auto clamp = [](float v) -> unsigned char {
    if(v > 255.0f) {
      return 255;
    } else {
      return static_cast<unsigned char>(static_cast<int>(v));
    }
  };

  const auto g = !vector(-3.1f, -16.f, 1.9f);
  const auto a = !(vector(0.0f, 0.0f, 1.0f)^g) * .002f;
  const auto b = !(g^a)*.002f;
  const auto c = (a+b)*-256.0f+g;
  const auto ar = 512.0f / static_cast<float>(imageSize);
  const auto orig0 = vector(-5.0f, 16.0f, 8.0f);

  auto lambda=[&](unsigned int seed, int offset, int jump) {
    for (int y=offset; y<imageSize; y+=jump) {    //For each row
      int k = (imageSize - y - 1) * imageSize * 3;

      for(int x=imageSize;x--;) {
        vector p(13.0f,13.0f,13.0f);

        for(int r=64;r--;) {
          const auto t = a*((rnd(seed)-.5f)*99.0f) + b*((rnd(seed)-.5f)*99.0f);

          const auto orig = orig0 + t;
          const auto js = 16.0f;
          const auto jt = -1.0f;
          const auto ja = js * (static_cast<float>(x) * ar + rnd(seed));
          const auto jb = js * (static_cast<float>(y) * ar + rnd(seed));
          const auto jc = js;
          const auto dir = !(t*jt + a*ja + b*jb + c*jc);

          const auto s = sampler(objects, orig, dir, seed);
          p = s * 3.5f + p;
        }

        bytes[k++] = clamp(p.x());
        bytes[k++] = clamp(p.y());
        bytes[k++] = clamp(p.z());
      }
    }
  };

  for(int iTimes = 0; iTimes < cl.times; ++iTimes) {
    std::mt19937 rgen;
    std::vector<std::thread> threads;
    for(int i = 0; i < cl.procs; ++i) {
      threads.emplace_back(lambda, rgen(), i, cl.procs);
    }
    for(auto& t : threads) {
      t.join();
    }
  }

  const auto overallDurationEnd = Clock::now();
  const auto overallDuration = static_cast<ClockSec>(overallDurationEnd - overallDurationBegin);
  outlog << "Average time taken " << (overallDuration.count() / cl.times) << "s" << std::endl;

  std::ofstream output(cl.outputFilename);
  output << "P6 " << imageSize << " " << imageSize << " 255 "; // The PPM Header is issued
  output.write(reinterpret_cast<char*>(bytes.data()), bytes.size());
}
