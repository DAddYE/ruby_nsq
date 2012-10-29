require 'thread'

module NSQ
  #:nodoc:
  class Timer
    def initialize(selector)
      @selector   = selector
      @proc_array = []
      @mutex      = Mutex.new
    end

    def add(interval, &block)
      new_run_at = Time.now + interval
      @mutex.synchronize do
        old_next_pair = @proc_array.first
        @proc_array << [new_run_at, block]
        # Sort the proc_array so the next one to run is at the front
        @proc_array.sort_by { |pair| pair.first }
        new_next_pair = @proc_array.first
        # If the next proc has changed, then wakeup the selector so we can set the new next time
        @selector.wakeup unless new_next_pair == old_next_pair
      end
    end

    # Execute any necessary procs and return the next interval or nil if no procs
    def next_interval
      now = Time.now
      @mutex.synchronize do
        loop do
          run_at, proc = @proc_array.first
          return nil unless run_at
          interval = run_at - now
          return interval if interval > 0
          proc.call
          @proc_array.shift
        end
      end
    end
  end
end
