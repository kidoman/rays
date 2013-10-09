require 'optparse'

require_relative 'art'
require_relative 'camera'
require_relative 'image'
require_relative 'raytracer'

options = {
  megapixels: 1.0,
  times: 1,
  procs: 8,
  output: 'render.ppm',
  art: 'ART',
  home: ENV['RAYS_HOME']
}

OptionParser.new do |o|
  o.banner = "Usage: #{__FILE__} [options]"

  o.on '-m', '--megapixels <float>',
      "Megapixels are the rendered image [#{options[:megapixels]}]" do |v|
    options[:megapixels] = v.to_f
  end

  o.on '-t', '--times <integer>',
      "Times to repeat the benchmark [#{options[:times]}]" do |v|
    options[:times] = v.to_i
  end

  o.on '-p', '--procs <integer>',
      "Number of threads [#{options[:procs]}]" do |v|
    options[:procs] = v.to_i
  end

  o.on '-o', '--output <string>',
      "Output file to write the rendered image [#{options[:output]}]" do |v|
    options[:output] = v
  end

  o.on '-a', '--art <string>',
      "Art file to use for rendering [#{options[:art]}]" do |v|
    options[:art] = v
  end

  o.on '-h', '--home <string>',
      "RAYS directory [#{options[:home]}]" do |v|
    options[:home] = v
  end
end.parse!

size = Math.sqrt(options[:megapixels] * 1000000).to_i
aspect_ratio = 512.0 / size

options[:times].times do
  art = Art.from_file(File.join(options[:home], options[:art]))
  raytracer = Raytracer.new(art.to_objects)
  image = Image.new(size, size)

  Array.new(options[:procs]) do |id|
    Thread.new do
      (id...size).step(options[:procs]) do |y|
        k = (size - y - 1) * size * 3

        (size - 1).downto(0) do |x|
          p = Vector.new(13, 13, 13)

          # cast 64 rays per pixel
          64.times do
            # delta to apply to the origin of view for DOF
            t = (Camera::A * (rand() - 0.5)) * 99 + (Camera::B * (rand() - 0.5)) * 99

            # camera focal point
            o = Camera::ORIGIN + t

            # ray direction with random deltas for stochastic sampling
            cam_a = Camera::A * (rand() + x * aspect_ratio)
            cam_b = Camera::B * (rand() + y * aspect_ratio)
            cam_c = cam_a + cam_b + Camera::C
            d = (t * -1 + cam_c * 16).norm

            # pixel color accumulator
            p = raytracer.sample(o, d) * 3.5 + p
          end

          image[k] = p.x.to_i
          image[k+1] = p.y.to_i
          image[k+2] = p.z.to_i

          k += 3
        end
      end
    end
  end.each(&:join)

  if options[:output] == '-'
    puts image.to_ppm
  else
    image.save(options[:output])
  end
end
