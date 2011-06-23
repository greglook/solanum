# Solanum monitoring configuration for hardware sensor metrics.
#
# Author:: Greg Look

# hardware sensor data
run "sensors" do
  match /^Core 0:\s+\+(\d+\.\d+)°C/, :record => "system.sensor.coretemp", :as => :to_f, :unit => :C
  match /^temp1:\s+\+(\d+\.\d+)°C/,  :record => "system.sensor.temp1",  :as => :to_f, :unit => :C
  match /^temp2:\s+\+(\d+\.\d+)°C/,  :record => "system.sensor.temp2",  :as => :to_f, :unit => :C
  match /^temp3:\s+\+(\d+\.\d+)°C/,  :record => "system.sensor.temp3",  :as => :to_f, :unit => :C
end
