# Solanum monitoring configuration for firewall traffic metrics.
#
# Author:: Greg Look

LO_IF = 'lo'
LAN_IF = 'br0'
WAN_IF = 'ppp0'

BYTE_KBITS = 8.0/1024

metrics_helpers do
  
  # Records simple network traffic metrics based on cumulative transferred
  # byte and packet counts.
  def record_traffic(name, packets, bytes)
    metric = get_metric name
    metric.record_rate :pps, packets, :packets
    metric.record_rate :kbit, bytes, :bytes, BYTE_KBITS
  end
  
end

input_helpers do
  
  # Matches an iptables rule and records traffic statistics.
  def match_rule(name, props={})
    pattern = /^\s*(\d+)\s+(\d+)\s+#{props[:target] || 'ACCEPT'}\s+#{props[:proto] || 'all'}\s+\-\-\s+#{props[:in] || 'any'}\s+#{props[:out] || 'any'}\s+#{props[:source] || 'anywhere'}\s+#{props[:dest] || 'anywhere'}\s*#{props[:match] || ''}/
    match pattern do |m| record_traffic name, m[1].to_i, m[2].to_i end
  end
  
end

# FILTER:INPUT chain
run "iptables --list INPUT --verbose --exact" do
  match /^Chain INPUT \(policy (\w+) (\d+) packets, (\d+) bytes\)/ do |m|
    record "firewall.filter.input.policy", m[1].to_s
    record_traffic "firewall.filter.input.default", m[2].to_i, m[3].to_i
  end
  match_rule "firewall.filter.input.lan", :in => LAN_IF
  match_rule "firewall.filter.input.loopback", :in => LO_IF
  match_rule "firewall.filter.input.established", :in => WAN_IF, :match => 'state RELATED,ESTABLISHED'
end

# FILTER:OUTPUT chain
run "iptables --list OUTPUT --verbose --exact" do
  match /^Chain OUTPUT \(policy (\w+) (\d+) packets, (\d+) bytes\)/ do |m|
    record "firewall.filter.output.policy", m[1].to_s
    record_traffic "firewall.filter.output.default", m[2].to_i, m[3].to_i
  end
end

# FILTER:FORWARD chain
run "iptables --list FORWARD --verbose --exact" do
  match /^Chain FORWARD \(policy (\w+) (\d+) packets, (\d+) bytes\)/ do |m|
    record "firewall.filter.forward.policy", m[1].to_s
    record_traffic "firewall.filter.forward.default", m[2].to_i, m[3].to_i
  end
  match_rule "firewall.filter.forward.lan", :in => LAN_IF
  match_rule "firewall.filter.forward.established", :match => 'state RELATED,ESTABLISHED'
end

# MANGLE:mark_qos_band chain
run "iptables --table mangle --list mark_qos_band --verbose --exact" do
  match_rule "firewall.mangle.qos.band1", :target => 'RETURN', :match => 'mark match 0x1'
  match_rule "firewall.mangle.qos.band2", :target => 'RETURN', :match => 'mark match 0x2'
  match_rule "firewall.mangle.qos.band3", :target => 'RETURN', :match => 'mark match 0x3'
  match_rule "firewall.mangle.qos.band4", :target => 'RETURN', :match => 'mark match 0x4'
  match_rule "firewall.mangle.qos.band5", :target => 'RETURN', :match => 'mark match 0x5'
end
