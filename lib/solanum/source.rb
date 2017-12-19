class Solanum
class Source
  attr_reader :period, :attributes, :tags

  def initialize(opts)
    @period = (opts[:period] || 10).to_i
    @attributes = opts[:attributes]
    @tags = opts[:tags]
  end

  def collect!
    raise "Not Yet Implemented"
  end

end
end
