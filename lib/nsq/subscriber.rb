module NSQ
  class Subscriber
    include NSQ::Logger

    attr_reader :selector
    attr_accessor :max_in_flight

    # Creates a new subscriber which maintain connections to all the nsqd instances which publish
    # the given topic.  This is never called directly but instead called when Reader#subscribe is called.
    #
    # Options:
    #   :max_tries [Integer]
    #     The max number of attempts to process a given message at which point it will no longer be requeued.
    #     Defaults to nil which means it will be requeued forever if it continues to fail.
    #
    #   :max_in_flight [Integer]
    #     The number used to determine the RDY count sent for each connection.
    #     Defaults to 1
    #
    #   :requeue_delay (msec) [Integer]
    #     The delay that is sent along with the requeue when a message fails.
    #     Defaults to 90,000 msec
    #
    #   :ready_backoff_timer [Hash of BackoffTimer options]
    #     Options passed to a BackoffTimer for increasing the interval between ready counts when
    #     messages are failing.
    #       Options:
    #         :min_interval (seconds) [Float]
    #           The minimum interval that the BackoffTimer will return.
    #           Defaults to 0
    #
    #         :max_interval (seconds) [Float]
    #           The maximum interval that the BackoffTimer will return.
    #           Defaults to 120
    #
    #         :ratio [Float]
    #           Defaults to 0.25
    #
    #         :short_length [Float]
    #           Defaults to 10
    #
    #         :long_length [Float]
    #           Defaults to 250
    #
    #   :connection_backoff_timer [Hash of BackoffTimer options]
    #     Options passed to a BackoffTimer for increasing the interval between connection attempts
    #     when a connection to nsqd is failing.
    #       Options (Refer to :ready_backoff_timer above for the meaning of these options):
    #         :min_interval (seconds) [Float]
    #           Defaults to 0
    #
    #         :max_interval (seconds) [Float]
    #           Defaults to 30
    #
    def initialize(reader, topic, channel, options, &block)
      options          = reader.options.merge(options)
      @reader          = reader
      @selector        = reader.selector
      @topic           = topic
      @channel         = channel
      @block           = block
      @max_tries       = options[:max_tries]
      @max_in_flight   = (options[:max_in_flight] || 1).to_i
      @requeue_delay   = (options[:requeue_delay] || 90).to_i * 1000
      @connection_hash = {}

      ready_options      = options[:ready_backoff_timer]           || {}
      connection_options = options[:connection_backoff_timer]      || {}

      @ready_min_interval      = ready_options[:min_interval]      || 0
      @ready_max_interval      = ready_options[:max_interval]      || 120
      @ready_ratio             = ready_options[:ratio]             || 0.25
      @ready_short_length      = ready_options[:short_length]      || 10
      @ready_long_length       = ready_options[:long_length]       || 250

      @connection_min_interval = connection_options[:min_interval] || 0
      @connection_max_interval = connection_options[:max_interval] || 30
      @connection_ratio        = connection_options[:ratio]        || 0.25
      @connection_short_length = connection_options[:short_length] || 10
      @connection_long_length  = connection_options[:long_length]  || 250

      raise "Invalid value for max_in_flight, must be between 0 and 2500: #{@max_in_flight}" unless @max_in_flight.between?(1,2499)
    end

    def create_ready_backoff_timer #:nodoc:
      BackoffTimer.new(@ready_min_interval, @ready_max_interval, @ready_ratio, @ready_short_length, @ready_long_length)
    end

    def create_connection_backoff_timer #:nodoc:
      BackoffTimer.new(@connection_min_interval, @connection_max_interval, @connection_ratio, @connection_short_length, @connection_long_length)
    end

    # Threshold for a connection where it's time to send a new READY message
    def ready_threshold #:nodoc:
      @max_in_flight / @connection_hash.size / 4
    end

    # The actual value for the READY message
    def ready_count #:nodoc:
      # TODO: Should we take into account the last_ready_count minus the number of messages sent since then?
      # Rounding up!
      (@max_in_flight + @connection_hash.size - 1) / @connection_hash.size
    end

    def connection_count #:nodoc:
      @connection_hash.size
    end

    def add_connection(host, port) #:nodoc:
      @connection_hash[[host, port]] = Connection.new(@reader, self, host, port)
    end

    def remove_connection(host, port) #:nodoc:
      connection = @connection_hash.delete([host, port])
      return unless connection
      connection.close
    end

    # Stop this subscriber
    def stop
      @stopped = true
      @connection_hash.each_value(&:close)
      @connection_hash.clear
    end

    # Return true if this subscriber has been stopped
    def stopped?
      @stopped
    end

    def handle_connection(connection) #:nodoc:
      connection.send_init(@topic, @channel)
    end

    def handle_heartbeat(connection) #:nodoc:
    end

    def handle_message(connection, message) #:nodoc:
      process_message(connection, message, &@block)
    end

    def process_message(connection, message, &block) #:nodoc:
      block[message]
      connection.send_finish(message.id, true)
    rescue Exception => e
      logger.error("Exception during handle_message: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
      if @max_tries && message.attempts >= @max_tries
        logger.warning("Giving up on message after #{@max_tries} tries: #{message.body.inspect}")
        connection.send_finish(message.id, false)
      else
        connection.send_requeue(message.id, message.attempts * @requeue_delay)
      end
    end

    def handle_frame_error(connection, error_message) #:nodoc:
      logger.error("Received error from nsqd: #{error_message.inspect}")
      connection.reset
    end

    def handle_io_error(connection, exception) #:nodoc:
      logger.error("Socket error: #{exception.message}\n\t#{exception.backtrace[0,2].join("\n\t")}")
      connection.reset
    end
  end
end
