require_relative 'art'
require_relative 'camera'
require_relative 'image'
require_relative 'raytracer'

width = (ARGV[0] && ARGV[0].to_i) || 768
height = (ARGV[1] && ARGV[1].to_i) || 768
threads = (ARGV[2] && ARGV[2].to_i) || 8

art = Art.new
raytracer = Raytracer.new(art.to_objects)
image = Image.new(width, height)

Array.new(threads) do |id|
  Thread.new do
    (id...height).step(threads) do |y|
      k = (height - y - 1) * width * 3

      (width - 1).downto(0) do |x|
        p = Vector.new(13, 13, 13)

        # cast 64 rays per pixel
        64.times do
          # delta to apply to the origin of view for DOF
          t = (Camera::A * (rand() - 0.5)) * 99 + (Camera::B * (rand() - 0.5)) * 99

          # camera focal point
          o = Vector.new(17, 16, 8) + t

          # ray direction with random deltas for stochastic sampling
          d = ((t * -1) + (((Camera::A * (rand() + x)) + (Camera::B * (rand() + y)) + Camera::C) * 16)).norm

          # pixel color accumulator
          p = raytracer.sample(o, d) * 3.5 + p
        end

        image.data[k] = p.x.to_i
        image.data[k+1] = p.y.to_i
        image.data[k+2] = p.z.to_i

        k += 3
      end
    end
  end
end.each(&:join)

puts image.to_ppm
