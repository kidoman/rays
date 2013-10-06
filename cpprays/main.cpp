#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <cstring>
#include <random>
#include <thread>
#include <vector>
#include <string>

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

typedef std::vector<vector> Objects;

Objects objects;

typedef std::vector<std::string> Art;

Objects makeObjects(const Art& art) {
  Objects o;
  auto y = 1.0f - static_cast<float>(art.size());
  for(const auto& line : art) {
    auto x = 1.0f - static_cast<float>(line.size());
    for(const auto& c : line) {
      if(' ' != c) {
        o.emplace_back(x, 3, y - 4);
      }
      x += 1.0f;
    }
    y += 1.0f;
  }
  return o;
}

float rnd(unsigned int& seed) {
  seed += seed;
  seed ^= 1;
  if ((int)seed < 0)
    seed ^= 0x88888eef;
  return (float)(seed % 95) / (float)95;
}

enum class Status {
  kMissUpward,
  kMissDownward,
  kHit
};

Status tracer(const Objects& objects, vector o, vector d, float& t, vector& n) {
  t=1e9;
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
      c = p%p-1,
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
    l=!(vector(9+rnd(seed),9+rnd(seed),16)+h*-1);

  float b=l%n;

  if(b < 0 || tracer(objects, h, l, t, n) != Status::kMissUpward)
    b=0;

  if(m == Status::kMissDownward) {
    h=h*.2f;
    return((int)(ceil(h.x())+ceil(h.y()))&1?vector(3,1,1):vector(3,3,3))*(b*.2f+.1f);
  }

  const vector r=d+on*(on%d*-2);               // r = The half-vector

  float p=l%r*(b>0);
  float p33 = p*p;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p;
  p = p33*p33*p33;

  return vector(p,p,p)+sampler(objects, h,r,seed)*.5;
}

int main(int argc, char **argv) {
  const Art art {
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
  };

  const auto objects = makeObjects(art);

  const auto getIntArg = [&](int argIndex, int defaultValue) {
    if(argc > argIndex) {
      return std::stoi(argv[argIndex]);
    }
    return defaultValue;
  };

  const auto w = getIntArg(1, 768);
  const auto h = getIntArg(2, 768);
  const auto num_threads = [&]() {
    int x = getIntArg(3, 0);
    if(x <= 0) {
      x = std::thread::hardware_concurrency();
      if(0 == x) {
        //8 threads is a reasonable assumption if we don't know how many cores there are
        x = 8;
      }
    }
    return x;
  }();

  printf("P6 %d %d 255 ", w, h); // The PPM Header is issued

  const vector g=!vector(-6.75f, -16.f, 1.f),
    a=!(vector(0,0,1)^g) * .002f,
    b=!(g^a)*.002f,
    c=(a+b)*-256+g;

  std::vector<char> bytes(3 * w * h);

  auto lambda=[&](unsigned int seed, int offset, int jump) {
    for (int y=offset; y<h; y+=jump) {    //For each row
      int k = (h - y - 1) * w * 3;

      for(int x=w;x--;) {
        vector p(13,13,13);

        for(int r=64;r--;) {
          const vector t=a*(rnd(seed)-.5f)*99+b*(rnd(seed)-.5f)*99;

          p=sampler(objects, vector(17,16,8)+t,
            !(t*-1+(a*(rnd(seed)+x)+b*(y+rnd(seed))+c)*16),
            seed)*3.5f+p;
        }

        bytes[k++] = (char)p.x();
        bytes[k++] = (char)p.y();
        bytes[k++] = (char)p.z();
      }
    }
  };

  std::mt19937 rgen;
  std::vector<std::thread> threads;
  for(int i=0;i<num_threads;++i) {
    threads.emplace_back(lambda, rgen(), i, num_threads);
  }
  for(auto& t : threads) {
    t.join();
  }

  fwrite(bytes.data(), sizeof(bytes[0]), bytes.size(), stdout);
}
