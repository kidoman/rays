class Image
  attr_reader :data

  def initialize(width, height)
    @width, @height = width, height
    @data = Array.new(3 * width * height, 0)
  end

  def to_ppm
    # binary portable pixmap
    ppm = "P6\n%d %d\n255\n" % [@width, @height]
    ppm + @data.pack('C*')
  end
end
