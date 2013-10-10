require 'json'

class Result
	def initialize
    @samples = []
  end

  def record(duration)
    @samples << duration
  end

  def save(path = 'result.json')
    File.write(path, to_json)
  end

  def to_json
    {
      average: @samples.reduce(&:+) / @samples.count,
      samples: @samples
    }.to_json
  end
end