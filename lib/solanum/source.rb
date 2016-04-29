class Solanum
class Source
  attr_accessor :period
  attr_reader :run_at

  def initialize(opts)
    @period = opts[:period].to_i || 10
    @run_at = Time.now + (rand * @period)
  end

  def collect!
    raise "Not Yet Implemented"
  end

end
end
