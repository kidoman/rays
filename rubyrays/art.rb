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

    height = @art.size

    @art.each_with_index do |row, i|
      row.each_char.each_with_index do |c, j|
        if c != ' '
          objects << Vector.new(j, 6.5, -(height - i) - 1)
        end
      end
    end

    objects
  end
end
