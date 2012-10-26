module NSQ
  class Subscriber
    attr_reader :selector, :name
    attr_accessor :max_in_flight

    def initialize(reader, topic, channel, options, &block)
      options          = reader.options.merge(options)
      @name            = "#{reader.name}:#{topic}:#{channel}"
      @reader          = reader
      @selector        = reader.selector
      @topic           = topic
      @channel         = channel
      @block           = block
      @max_tries       = options[:max_tries]
      @max_in_flight   = options[:max_in_flight]  || 1
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

    def create_ready_backoff_timer
      BackoffTimer.new(@ready_min_interval, @ready_max_interval, @ready_ratio, @ready_short_length, @ready_long_length)
    end

    def create_connection_backoff_timer
      BackoffTimer.new(@connection_min_interval, @connection_max_interval, @connection_ratio, @connection_short_length, @connection_long_length)
    end

    def connection_max_in_flight
      # TODO: Maybe think about this a little more
      val = @max_in_flight / [@connection_hash.size, 1].max
      [val, 1].max
    end

    def connection_count
      @connection_hash.size
    end

    def add_connection(host, port)
      @connection_hash[[host, port]] = Connection.new(@reader, self, host, port)
    end

    def remove_connection(host, port)
      connection = @connection_hash.delete([host, port])
      return unless connection
      connection.close
    end

    def stop
      @stopped = true
      @connection_hash.each_value do |connection|
        connection.close
      end
      @connection_hash.clear
    end

    def stopped?
      @stopped
    end

    def handle_connection(connection)
      connection.send_init(@topic, @channel, @reader.short_id, @reader.long_id, self.connection_max_in_flight)
    end

    def handle_heartbeat(connection)
    end

    def handle_message(connection, message)
      process_message(connection, message, &@block)
    end

    def process_message(connection, message, &block)
      yield message
      connection.send_finish(message.id)
      connection.message_success!
    rescue Exception => e
      NSQ.logger.error("#{connection.name}: Exception during handle_message: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
      if @max_tries && attempts >= @max_tries
        NSQ.logger.warning("#{connection.name}: Giving up on message after #{@max_tries} tries: #{body.inspect}")
        connection.send_finish(message.id)
      else
        connection.send_requeue(message.id, attempts * @requeue_delay)
      end
      connection.message_failure!
    ensure
      handle_ready_count(connection)
    end

    def handle_ready_count(connection)
      # TODO: Need to add 25% logic
      connection.send_ready(self.connection_max_in_flight)
    end

    def handle_frame_error(connection, error_message)
      NSQ.logger.error("Received error from nsqd: #{error_message.inspect}")
      connection.reset
    end

    def handle_io_error(connection, exception)
      NSQ.logger.error("Socket error: #{exception.message}\n\t#{exception.backtrace[0,2].join("\n\t")}")
      connection.reset
    end

    def to_s
      @name
    end
  end
end
