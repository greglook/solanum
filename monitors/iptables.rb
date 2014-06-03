##### IPTABLES SOURCE #####

class Solanum::Source::IPTables < Solanum::Source::Command
  def initialize(args)
    super("sudo -n iptables #{args}")
  end

  # Records packet and byte metrics for a given serivce name.
  def record_traffic(metrics, name, packets, bytes)
    metrics["#{name} packets"] = packets.to_i
    metrics["#{name} bytes"] = bytes.to_i
    metrics
  end

  # Matches an iptables chain header.
  def match_chain(name, chain)
    match /^Chain #{chain.upcase} \(policy \w+ (\d+) packets, (\d+) bytes\)/ do |m, metrics|
      record_traffic metrics, "iptables #{name}", m[1], m[2]
    end
  end

  # Matches an iptables rule and records traffic statistics.
  def match_rule(name, opts={})
    pattern = /^\s*(\d+)\s+(\d+)\s+#{opts[:target] || 'ACCEPT'}\s+#{opts[:proto] || 'all'}\s+\-\-\s+#{opts[:in] || 'any'}\s+#{opts[:out] || 'any'}\s+#{opts[:source] || 'anywhere'}\s+#{opts[:dest] || 'anywhere'}\s*#{opts[:match] || ''}/
    match pattern do |m, metrics|
      record_traffic metrics, "iptables #{name}", m[1], m[2]
    end
  end
end


# Shorthand for running iptables through sudo.
def iptables(args, &config)
  register_source Solanum::Source::IPTables.new(args), config
end



##### METRIC DEFINITIONS #####

# FILTER:INPUT chain
iptables "--list INPUT --verbose --exact" do
  match_chain "filter input DROP", "INPUT"             # Dropped traffic
  match_rule  "filter input lan0", in: 'lan0'          # Traffic to XVI from the LAN
  match_rule  "filter input established", in: 'wan0',  # Established traffic to XVI from Internet
              match: 'ctstate RELATED,ESTABLISHED'
end

# FILTER:OUTPUT chain
iptables "--list OUTPUT --verbose --exact" do
  match_chain "filter output", "OUTPUT"                # Traffic sent by XVI
end

# FILTER:FORWARD chain
iptables "--list FORWARD --verbose --exact" do
  match_chain "filter forward DROP", "FORWARD"
  match_rule  "filter forward lan0", in: 'lan0'        # Forwarded traffic from LAN to Internet
  match_rule  "filter forward established",            # Forward established traffic
              match: 'ctstate RELATED,ESTABLISHED'
end

# MANGLE:mark_qos_band chain
iptables "--table mangle --list mark_qos_band --verbose --exact" do
  match_rule "mangle qos band1", target: 'RETURN', match: 'mark match 0x1'
  match_rule "mangle qos band2", target: 'RETURN', match: 'mark match 0x2'
  match_rule "mangle qos band3", target: 'RETURN', match: 'mark match 0x3'
  match_rule "mangle qos band4", target: 'RETURN', match: 'mark match 0x4'
  match_rule "mangle qos band5", target: 'RETURN', match: 'mark match 0x5'
end

# Define services.
service /^iptables /, diff: true, tags: ["net"]
