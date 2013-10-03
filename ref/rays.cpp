#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <cstring>
#include <random>
#include <future>
#include <vector>

//Define a vector class with constructor and operator: 'v'
struct vector {
  float x,y,z;  // Vector has three float attributes.
  vector operator+(vector r){return vector(x+r.x,y+r.y,z+r.z);} //Vector add
  vector operator*(float r){return vector(x*r,y*r,z*r);}       //Vector scaling
  float operator%(vector r){return x*r.x+y*r.y+z*r.z;}    //Vector dot product
  vector(){}                                  //Empty constructor
  vector operator^(vector r){return vector(y*r.z-z*r.y,z*r.x-x*r.z,x*r.y-y*r.x);} //Cross-product
  vector(float a,float b,float c){x=a;y=b;z=c;}            //Constructor
  vector operator!(){return *this*(1 /sqrt(*this%*this));} // Used later for normalizing the vector
};

const char *art[] = {
  "                   ",
  "    1111           ",
  "   1    1          ",
  "  1           11   ",
  "  1          1  1  ",
  "  1     11  1    1 ",
  "  1      1  1    1 ",
  "   1     1   1  1  ",
  "    11111     11   "
};

struct object {
  int k,j;
  object(int x,int y){k=x;j=y;}
};

std::vector<object> objects;

void F() {
  int nr = sizeof(art) / sizeof(char *),
  nc = strlen(art[0]);
  for (int k = nc - 1; k >= 0; k--) {
    for (int j = nr - 1; j >= 0; j--) {
      if(art[j][nc - 1 - k] != ' ') {
        objects.push_back(object(k, nr - 1 - j));
      }
    }
  }
}

float R(unsigned int& seed) {
  seed += seed;
  seed ^= 1;
  if ((int)seed < 0)
    seed ^= 0x88888eef;
  return (float)(seed % 95) / (float)95;
}

//The intersection test for line [o,v].
// Return 2 if a hit was found (and also return distance t and bouncing ray n).
// Return 0 if no hit was found but ray goes upward
// Return 1 if no hit was found but ray goes downward
int T(vector o,vector d,float& t,vector& n) {
  t=1e9;
  int m=0;
  float p=-o.z/d.z;

  if(.01<p)
    t=p,n=vector(0,0,1),m=1;

  for (auto& obj : objects) {
    // There is a sphere but does the ray hits it ?
    vector p=o+vector(-obj.k,3,-obj.j-4);
    float b=p%d,c=p%p-1,q=b*b-c;

    // Does the ray hit the sphere ?
    if(q>0) {
      //It does, compute the distance camera-sphere
      float s=-b-sqrt(q);

      if(s<t && s>.01)
      // So far this is the minimum distance, save it. And also
      // compute the bouncing ray vector into 'n'
      t=s, n=!(p+d*t), m=2;
    }
  }

  return m;
}

// (S)ample the world and return the pixel color for
// a ray passing by point o (Origin) and d (Direction)
vector S(vector o,vector d, unsigned int& seed) {
  float t;
  vector n, on;

  //Search for an intersection ray Vs World.
  int m=T(o,d,t,n);
  on = n;

  if(!m) { // m==0
    //No sphere found and the ray goes upward: Generate a sky color
    float p = 1-d.z;
    p = p*p;
    p = p*p;
    return vector(.7,.6,1)*p;
  }

  //A sphere was maybe hit.

  vector h=o+d*t,                    // h = intersection coordinate
  l=!(vector(9+R(seed),9+R(seed),16)+h*-1);  // 'l' = direction to light (with random delta for soft-shadows).

  //Calculated the lambertian factor
  float b=l%n;

  //Calculate illumination factor (lambertian coefficient > 0 or in shadow)?
  if(b<0||T(h,l,t,n))
    b=0;

  if(m&1) {   //m == 1
    h=h*.2; //No sphere was hit and the ray was going downward: Generate a floor color
    return((int)(ceil(h.x)+ceil(h.y))&1?vector(3,1,1):vector(3,3,3))*(b*.2+.1);
  }

  vector r=d+on*(on%d*-2);               // r = The half-vector

  // Calculate the color 'p' with diffuse and specular component
  float p=l%r*(b>0);
  float p33 = p*p;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p;
  p = p33*p33*p33;

  //m == 2 A sphere was hit. Cast an ray bouncing from the sphere surface.
  return vector(p,p,p)+S(h,r,seed)*.5; //Attenuate color by 50% since it is bouncing (* .5)
}

// The main function. It generates a PPM image to stdout.
// Usage of the program is hence: ./card > erk.ppm
int main(int argc, char **argv) {
  F();

  int w = 512,
  h = 512;

  if (argc > 1) {
    w = atoi(argv[1]);
  }
  if (argc > 2) {
    h = atoi(argv[2]);
  }

  printf("P6 %d %d 255 ", w, h); // The PPM Header is issued

  // The '!' are for normalizing each vectors with ! operator.
  vector g=!vector(-5.5,-16,0),       // Camera direction
    a=!(vector(0,0,1)^g)*.002, // Camera up vector...Seem Z is pointing up :/ WTF !
    b=!(g^a)*.002,        // The right vector, obtained via traditional cross-product
    c=(a+b)*-256+g;       // WTF ? See https://news.ycombinator.com/item?id=6425965 for more.

  int s = 3*w*h;
  char *bytes = new char[s];

  std::mt19937 rgen;
  std::vector<std::future<void>> wg;
  for(int y=h;y--;) {    //For each row
    wg.push_back(std::async(std::launch::async, [&, y](unsigned int seed) {
      int k = (h - (y+1)) * w * 3;
      for(int x=w;x--;) {   //For each pixel in a line
        //Reuse the vector class to store not XYZ but a RGB pixel color
        vector p(13,13,13);     // Default pixel color is almost pitch black

        //Cast 64 rays per pixel (For blur (stochastic sampling) and soft-shadows.
        for(int r=64;r--;) {
          // The delta to apply to the origin of the view (For Depth of View blur).
          vector t=a*(R(seed)-.5)*99+b*(R(seed)-.5)*99; // A little bit of delta up/down and left/right

          // Set the camera focal point vector(17,16,8) and Cast the ray
          // Accumulate the color returned in the p variable
          p=S(vector(17,16,8)+t, //Ray Origin
          !(t*-1+(a*(R(seed)+x)+b*(y+R(seed))+c)*16) // Ray Direction with random deltas
                                                     // for stochastic sampling
          , seed)*3.5+p; // +p for color accumulation
        }

        bytes[k++] = (char)p.x;
        bytes[k++] = (char)p.y;
        bytes[k++] = (char)p.z;
      }
    }, rgen()));
  }
  for(auto& w : wg) {
    w.wait();
  }

  fwrite(bytes, 1, s, stdout);
  delete [] bytes;
}
