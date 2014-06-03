# encoding: utf-8

# Hardware sensor data.
run "sensors" do
  match /^Core 0:\s+\+(\d+\.\d+)°C/, record: "sensor coretemp", cast: :to_f
  match /^temp1:\s+\+(\d+\.\d+)°C/,  record: "sensor temp1",    cast: :to_f
  match /^temp2:\s+\+(\d+\.\d+)°C/,  record: "sensor temp2",    cast: :to_f
  match /^temp3:\s+\+(\d+\.\d+)°C/,  record: "sensor temp3",    cast: :to_f
end

service "sensor coretemp", state: thresholds(:ok, 45.0, :warning, 55.0, :critical)
service "sensor temp1",    state: thresholds(:ok, 50.0, :warning, 60.0, :critical)
service "sensor temp2",    state: thresholds(:ok, 65.0, :warning, 75.0, :critical)
service "sensor temp3",    state: thresholds(:ok, 60.0, :warning, 70.0, :critical)
