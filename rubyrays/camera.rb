require_relative 'vector'

class Camera
  G = Vector.new(-5.5, -16, 0).norm
  A = (Vector::NORMAL.cross(G)).norm * 0.002
  B = (G.cross(A)).norm * 0.002
  C = (A + B) * -256 + G
end
