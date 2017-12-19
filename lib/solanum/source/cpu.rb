require 'solanum/source'

class Solanum::Source::Cpu < Solanum::Source

  STATES = %w{user nice system idle iowait irqhard irqsoft}


  def initialize(opts)
    super(opts)
    @last = nil
    # TODO: per_cpu option
  end


  def collect!
    header = File.readlines('/proc/stat').first.chomp.split(' ').drop(1)
    current = Hash.new(0)
    diff = Hash.new(0)

    # calculate cpu utilization from the cumulative time spent in
    # 'jiffies' (1/100 sec) since system boot
    STATES.each_with_index do |name, i|
      jiffies = header[i].to_i
      current[name] = jiffies
      diff[name] = jiffies - @last[name] if @last
    end

    diff_total = diff.values.reduce(&:+)
    diff.keys.each do |name|
      diff[name] = diff[name].to_f/diff_total
    end

    @last = current
    puts diff.inspect # DEBUG

    []
  end

end
