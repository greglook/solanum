class Solanum
class Source
  attr_reader :type, :period, :attributes

  def initialize(opts)
    @type = opts['type']
    @period = (opts['period'] || 10).to_i
    @attributes = opts['attributes']
  end


  def collect!
    raise "Not Yet Implemented"
  end


  def next_run(from=Time.now)
    jitter = 0.95 + 0.10*rand
    from + jitter*@period
  end


  # Calculate the state of a metric.
  def event_state(metric)
    crit_at = @thresholds['critical']
    warn_at = @thresholds['warning']
    if crit_at && crit_at <= metric
      'critical'
    elsif warn_at && warn_at <= metric
      'warning'
    else
      'ok'
    end
  end

end
end
