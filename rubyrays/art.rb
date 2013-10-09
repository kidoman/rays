require_relative 'vector'

class Art
  def self.from_file(pathname)
    lines = File.readlines(pathname).map(&:chomp)
    new(lines)
  end

  def initialize(art)
    @art = art
  end

  def to_objects
    objects = []

    (width - 1).downto(0) do |k|
      (height - 1).downto(0) do |j|
        if @art[j][width - 1 - k] != ' '
          objects << Vector.new(-k, 0, -(height - 1 -j))
        end
      end
    end

    objects
  end

  private

  def width
    @art[0].size
  end

  def height
    @art.size
  end
end
