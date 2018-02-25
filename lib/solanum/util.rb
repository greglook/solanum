# Miscellaneous helper functions.


# Return a human-friendly duration string for the given duration in seconds.
def duration_str(duration)
  days = (duration/86400).to_i
  hours = ((duration % 86400)/3600).to_i
  minutes = ((duration % 3600)/60).to_i
  seconds = (duration % 60).to_i
  hms = "%02d:%02d:%02d" % [hours, minutes, seconds]

  if 0 < days
    "#{days} days, #{hms}"
  else
    hms
  end
end


# Calculate the state of a metric by comparing it to the given thresholds. The
# metric is compared to each threshold in turn, largest to smallest. The first
# threshold the metric is larger than is returned, or the 'min_sate' is
# returned.
def state_over(thresholds, metric, min_state='ok')
  thresholds.sort_by {|e| -e[1] }.each do |threshold_entry|
    key, threshold = *threshold_entry
    return key if threshold <= metric
  end
  return min_state
end


# Calculate the state of a metric by comparing it to the given thresholds. The
# metric is compared to each threshold in turn, smallest to largest. The first
# threshold the metric is smaller than is returned, or the 'max_state' is
# returned.
def state_under(thresholds, metric, max_state='ok')
  thresholds.sort_by {|e| e[1] }.each do |threshold_entry|
    key, threshold = *threshold_entry
    return key if threshold > metric
  end
  return max_state
end
