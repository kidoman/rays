class Vector
  attr_reader :x, :y, :z

  def initialize(x = 0.0, y = 0.0, z = 0.0)
    @x, @y, @z = x.to_f, y.to_f, z.to_f
  end

  def *(other)
    Vector.new(x * other, y * other, z * other)
  end

  def +(other)
    Vector.new(x + other.x, y + other.y, z + other.z)
  end

  def cross(other)
    x = @y * other.z - @z * other.y
    y = @z * other.x - @x * other.z
    z = @x * other.y - @y * other.x
    Vector.new(x, y, z)
  end

  def dot(other)
    x * other.x + y * other.y + z * other.z
  end

  def norm
    self * (1.0 / Math.sqrt(dot(self)))
  end

  ZEROS = new(0, 0, 0)
  NORMAL = new(0, 0, 1)
end
