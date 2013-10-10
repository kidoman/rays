require_relative 'vector'

class Camera
  G = Vector.new(-3.1, -16, 1.9).norm

  A = (Vector::NORMAL.cross(G)).norm * 0.002
  B = (G.cross(A)).norm * 0.002
  C = (A + B) * -256 + G

  ORIGIN = Vector.new(-5, 16, 8)
end
