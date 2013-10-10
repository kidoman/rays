require_relative 'vector'

class Raytracer
  SKY = Vector.new(1, 1, 1)

  FLOOR_PATTERN_1 = Vector.new(3, 1, 1)
  FLOOR_PATTERN_2 = Vector.new(3, 3, 3)

  def initialize(objects = [])
    @objects = objects
  end

  def sample(o, d)
    # find an intersection ray vs world
    m, t, n = trace(o, d)

    if m == :miss_upward
      # the ray hits the sky
      p = 1 - d.z
      return SKY * p
    end

    # intersection coordinate
    h = o + (d * t)

    # direction of light
    l = (Vector.new(9 + rand(), 9 + rand(), 16) + (h * -1)).norm

    # b = Lambertian factor
    b = l.dot(n)

    # illumination factor
    if b < 0
      b = 0
    else
      m2, *_ = trace(h, l)
      b = 0 if m2 != :miss_upward
    end

    if m == :miss_downward
      # the ray hits the floor
      h = h * 0.2

      pattern =
        if (h.x.ceil + h.y.ceil) & 1 == 1
          FLOOR_PATTERN_1
        else
          FLOOR_PATTERN_2
        end

      return pattern * (b * 0.2 + 0.1)
    end

    # the half-vector
    r = d + (n * n.dot(d * -2))

    # color with diffuse and specular components
    p = l.dot(r * (b > 0 ? 1 : 0))
    p33 = p * p
    p33 = p33 * p33
    p33 = p33 * p33
    p33 = p33 * p33
    p33 = p33 * p33
    p33 = p33 * p
    p = p33 * p33 * p33

    # a sphere was hit; cast a ray bouncing from the sphere surface
    # and attenuate the color by 50%
    Vector.new(p, p, p) + (sample(h, r) * 0.5)
  end

  private

  def trace(o, d)
    t = 1E9
    m = :miss_upward
    p = -o.z / d.z

    n = Vector::ZEROS

    if (0.01 < p)
      t = p
      m = :miss_downward
      n = Vector::NORMAL
    end

    @objects.each do |object|
      p1 = o + object

      b = p1.dot(d)
      c = p1.dot(p1) - 1
      q = b * b - c

      if q > 0
        # the ray intersects the sphere

        # camera-sphere distance
        s = -b - Math.sqrt(q)

        if s < t && s > 0.01
          t = s
          n = (p1 + (d * t)).norm
          m = :hit
        end
      end
    end

    [m, t, n]
  end
end
