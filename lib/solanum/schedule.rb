# Schedule management class.
class Solanum
class Schedule

  def initialize
    @lock = Mutex.new
    @timetable = []
  end


  # Peek at the next scheduled entry.
  def peek_next
    @lock.synchronize do
      @timetable.first
    end
  end


  # Time to spend waiting until the next scheduled entry. Returns a number of
  # seconds, or nil if the schedule is empty.
  def next_wait
    entry = peek_next
    if entry
      next_time, next_id = *entry
      duration = next_time - Time.now
      puts "Next scheduled run for #{next_id} at #{next_time} in #{duration} seconds" # DEBUG
      duration
    end
  end


  # Try to get the next ready entry. Returns the id if it is ready and removes
  # it from the scheudle, otherwise nil if no entries are ready to run.
  def pop_ready!
    @lock.synchronize do
      if @timetable.first && Time.now >= @timetable.first[0]
        entry = @timetable.shift
        entry[1]
      end
    end
  end


  # Schedule the given id for later running. Returns the scheduled entry.
  def insert!(time, id)
    entry = [time, id]
    @lock.synchronize do
      @timetable << entry
      @timetable.sort_by! {|e| e[0] }
    end
    entry
  end

end
end
