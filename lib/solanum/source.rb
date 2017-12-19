class Solanum
class Source
  attr_reader :type, :period, :attributes

  def initialize(opts)
    @type = opts['type']
    @period = (opts['period'] || 10).to_i
    @attributes = opts['attributes']
  end


  def next_run(from=Time.now)
    jitter = 0.95 + 0.10*rand
    from + jitter*@period
  end


  def collect!
    raise "Not Yet Implemented"
  end

end
end
