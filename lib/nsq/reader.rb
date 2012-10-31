require 'socket'
require 'thread'
require 'monitor'
require 'nio'

module NSQ
  # Maintains a collection of subscribers to topics and channels.
  class Reader
    attr_reader :name, :long_id, :short_id, :selector, :options

    # Create a new NSQ Reader
    #
    # Options (Refer to NSQ::Subscriber::new for additional options which will be passed on to each subscriber):
    #   :nsqd_tcp_addresses [String or Array of Strings]
    #     Array of nsqd servers to connect to with port numbers
    #     ['server1:4150', 'server2:4150']
    #
    #   :lookupd_tcp_addresses [String or Array of Strings] (Not implemented)
    #     Array of nsq_lookupd servers to connect to with port numbers
    #     ['server1:4160', 'server2:4160']
    #
    #   :lookupd_poll_interval [Float] (Not implemented)
    #     How often to poll the lookupd_tcp_addresses for new nsqd servers
    #     Default: 120
    #
    #   :long_id [String]
    #     The identifier used as a long-form descriptor
    #     Default: fully-qualified hostname
    #
    #   :short_id [String]
    #     The identifier used as a short-form descriptor
    #     Default: short hostname
    #
    def initialize(options={})
      @options                = options
      @nsqd_tcp_addresses     = s_to_a(options[:nsqd_tcp_addresses])
      @lookupd_tcp_addresses  = s_to_a(options[:lookupd_tcp_addresses])
      @lookupd_poll_interval  = options[:lookupd_poll_interval]        || 120
      @long_id                = options[:long_id]                      || Socket.gethostname
      @short_id               = options[:short_id]                     || @long_id.split('.')[0]
      NSQ.logger              = options[:logger] if options[:logger]
      NSQ.logger.level        = options[:logger_level] if options[:logger_level]

      @selector               = ::NIO::Selector.new
      @timer                  = Timer.new(@selector)
      @topic_count            = Hash.new(0)
      @subscribers            = {}
      @subscriber_mutex       = Monitor.new
      @name                   = "#{@long_id}:#{@short_id}"

      raise 'Must pass either option :nsqd_tcp_addresses or :lookupd_http_addresses' if @nsqd_tcp_addresses.empty? && @lookupd_http_addresses.empty?

      @conns = {}
      @last_lookup = nil

      @logger.info("starting reader for topic '%s'..." % self.topic) if @logger
    end

    # Subscribes to a given topic and channel.
    #
    # If a block is passed, then within NSQ::Reader#run that block will be run synchronously whenever a message
    # is received for this channel.
    #
    # If a block is not passed, then the QueueSubscriber that is returned from this method should have it's
    # QueueSubscriber#run method executed within one or more separate threads for processing the messages.
    #
    # Refer to Subscriber::new for the options that can be passed to this method.
    #
    def subscribe(topic, channel, options={}, &block)
      Util.assert_topic_and_channel_valid(topic, channel)
      subscriber = nil
      name       = "#{topic}:#{channel}"
      @subscriber_mutex.synchronize do
        raise "Already subscribed to #{name}" if @subscribers[name]
        subscriber_class = block_given? ? Subscriber : QueueSubscriber
        subscriber = @subscribers[name] = subscriber_class.new(self, topic, channel, options, &block)
      end

      @nsqd_tcp_addresses.each do |addr|
        address, port = addr.split(':')
        subscriber.add_connection(address, port.to_i)
      end
      subscriber
    end

    # Unsubscribe  a given topic and channel.
    def unsubscribe(topic, channel)
      name = "#{topic}:#{channel}"
      @subscriber_mutex.synchronize do
        subscriber = @subscribers[name]
        return unless subscriber
        subscriber.stop
        @subscribers.delete(name)
      end
    end

    # Processes all the messages from the subscribed connections.  This will not return until #stop
    # has been called in a separate thread.
    def run
      @stopped = false
      until @stopped do
        if (Time.now.to_i - @last_lookup.to_i) > @lookupd_poll_interval
          # Do lookupd
        end
        @selector.select(@timer.next_interval) { |m| m.value.call }
      end
    end

    # Stop this reader which will gracefully exit the run method after all current messages are processed.
    def stop
      NSQ.logger.info("#{self}: Reader stopping...")
      @stopped = true
      @selector.wakeup
      @subscriber_mutex.synchronize do
        @subscribers.each_value {|subscriber| subscriber.stop}
      end
    end

    # Call the given block from within the #run thread when the given interval has passed.
    def add_timeout(interval, &block)
      @timer.add(interval, &block)
    end

    def to_s #:nodoc:
      @name
    end

    private

    def s_to_a(val)
      val.kind_of?(String) ? [val] : val
    end
  end
end
