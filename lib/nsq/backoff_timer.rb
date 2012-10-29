# Stolen from pynsq library since somebodies thought about this a lot more than me
module NSQ
  # This is a timer that is smart about backing off exponentially when there are problems
  class BackoffTimer

    attr_reader :min_interval, :max_interval, :short_interval, :long_interval

    def initialize(min_interval, max_interval, ratio=0.25, short_length=10, long_length=250)
      @min_interval    = min_interval.to_f
      @max_interval    = max_interval.to_f
      ratio            = ratio.to_f

      @max_short_timer = (@max_interval - @min_interval) * ratio
      @max_long_timer  = (@max_interval - @min_interval) * (1.0 - ratio)
      @short_unit      = @max_short_timer / short_length
      @long_unit       = @max_long_timer / long_length

      @short_interval  = 0.0
      @long_interval   = 0.0
    end

    # Update the timer to reflect a successful call
    def success
      @short_interval -= @short_unit
      @long_interval  -= @long_unit
      @short_interval  = [@short_interval, 0.0].max
      @long_interval   = [@long_interval, 0.0].max
    end

    # Update the timer to reflect a failed call
    def failure
      @short_interval += @short_unit
      @long_interval  += @long_unit
      @short_interval  = [@short_interval, @max_short_timer].min
      @long_interval   = [@long_interval, @max_long_timer].min
    end

    # Return the interval to wait based on the successes and failures
    def interval
      @min_interval + @short_interval + @long_interval
    end
  end
end
