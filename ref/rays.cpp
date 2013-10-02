#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <list>

typedef int i;       //Save space by using 'i' instead of 'int'
typedef float f;     //Save even more space by using 'f' instead of 'float'

//Define a vector class with constructor and operator: 'v'
struct v {
  f x,y,z;  // Vector has three float attributes.
  v operator+(v r){return v(x+r.x,y+r.y,z+r.z);} //Vector add
  v operator*(f r){return v(x*r,y*r,z*r);}       //Vector scaling
  f operator%(v r){return x*r.x+y*r.y+z*r.z;}    //Vector dot product
  v(){}                                  //Empty constructor
  v operator^(v r){return v(y*r.z-z*r.y,z*r.x-x*r.z,x*r.y-y*r.x);} //Cross-product
  v(f a,f b,f c){x=a;y=b;z=c;}            //Constructor
  v operator!(){return *this*(1 /sqrt(*this%*this));} // Used later for normalizing the vector
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
  i k,j;
  object(i x,i y){k=x;j=y;}
};

std::list<object> objects;

void F() {
  i nr = sizeof(art) / sizeof(char *),
  nc = strlen(art[0]);
  for (int k = nc - 1; k >= 0; k--) {
    for (int j = nr - 1; j >= 0; j--) {
      if (art[j][nc - 1 - k] != ' ') {
        objects.push_back(object(k, nr - 1 - j));
      }
    }
  }
}

unsigned int seed = ~0;

f R() {
  seed += seed;
  seed ^= 1;
  if ((int)seed < 0)
    seed ^= 0x88888eef;
  return (f)(seed % 95) / (f)95;
}

//The intersection test for line [o,v].
// Return 2 if a hit was found (and also return distance t and bouncing ray n).
// Return 0 if no hit was found but ray goes upward
// Return 1 if no hit was found but ray goes downward
i T(v o,v d,f& t,v& n) {
  t=1e9;
  i m=0;
  f p=-o.z/d.z;

  if(.01<p)
    t=p,n=v(0,0,1),m=1;

  std::list<object>::iterator it;

  for (it = objects.begin(); it != objects.end(); ++it) {
    i k = it->k,
    j = it->j;

    // There is a sphere but does the ray hits it ?
    v p=o+v(-k,3,-j-4);
    f b=p%d,c=p%p-1,q=b*b-c;

    // Does the ray hit the sphere ?
    if(q>0) {
      //It does, compute the distance camera-sphere
      f s=-b-sqrt(q);

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
v S(v o,v d) {
  f t;
  v n, on;

  //Search for an intersection ray Vs World.
  i m=T(o,d,t,n);
  on = n;

  if(!m) { // m==0
    //No sphere found and the ray goes upward: Generate a sky color
    f p = 1-d.z;
    p = p*p;
    p = p*p;
    return v(.7,.6,1)*p;
  }

  //A sphere was maybe hit.

  v h=o+d*t,                    // h = intersection coordinate
  l=!(v(9+R(),9+R(),16)+h*-1);  // 'l' = direction to light (with random delta for soft-shadows).

  //Calculated the lambertian factor
  f b=l%n;

  //Calculate illumination factor (lambertian coefficient > 0 or in shadow)?
  if(b<0||T(h,l,t,n))
    b=0;

  if(m&1) {   //m == 1
    h=h*.2; //No sphere was hit and the ray was going downward: Generate a floor color
    return((i)(ceil(h.x)+ceil(h.y))&1?v(3,1,1):v(3,3,3))*(b*.2+.1);
  }

  v r=d+on*(on%d*-2);               // r = The half-vector

  // Calculate the color 'p' with diffuse and specular component
  f p=l%r*(b>0);
  f p33 = p*p;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p33;
  p33 = p33*p;
  p = p33*p33*p33;

  //m == 2 A sphere was hit. Cast an ray bouncing from the sphere surface.
  return v(p,p,p)+S(h,r)*.5; //Attenuate color by 50% since it is bouncing (* .5)
}

// The main function. It generates a PPM image to stdout.
// Usage of the program is hence: ./card > erk.ppm
i main(int argc, char **argv) {
  F();

  i w = 512,
  h = 512;

  if (argc > 1) {
    w = atoi(argv[1]);
  }
  if (argc > 2) {
    h = atoi(argv[2]);
  }

  printf("P6 %d %d 255 ", w, h); // The PPM Header is issued

  // The '!' are for normalizing each vectors with ! operator.
  v g=!v(-5.5,-16,0),       // Camera direction
    a=!(v(0,0,1)^g)*.002, // Camera up vector...Seem Z is pointing up :/ WTF !
    b=!(g^a)*.002,        // The right vector, obtained via traditional cross-product
    c=(a+b)*-256+g;       // WTF ? See https://news.ycombinator.com/item?id=6425965 for more.

  i s = 3*w*h;
  char *bytes = new char[s];
  int k = 0;

  for(i y=h;y--;)    //For each column
  for(i x=w;x--;) {   //For each pixel in a line
    //Reuse the vector class to store not XYZ but a RGB pixel color
    v p(13,13,13);     // Default pixel color is almost pitch black

    //Cast 64 rays per pixel (For blur (stochastic sampling) and soft-shadows.
    for(i r=64;r--;) {
      // The delta to apply to the origin of the view (For Depth of View blur).
      v t=a*(R()-.5)*99+b*(R()-.5)*99; // A little bit of delta up/down and left/right

      // Set the camera focal point v(17,16,8) and Cast the ray
      // Accumulate the color returned in the p variable
      p=S(v(17,16,8)+t, //Ray Origin
      !(t*-1+(a*(R()+x)+b*(y+R())+c)*16) // Ray Direction with random deltas
                                         // for stochastic sampling
      )*3.5+p; // +p for color accumulation
    }

    bytes[k++] = (char)p.x;
    bytes[k++] = (char)p.y;
    bytes[k++] = (char)p.z;
  }

  fwrite(bytes, 1, s, stdout);
  delete [] bytes;
}
