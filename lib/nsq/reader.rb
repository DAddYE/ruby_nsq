require 'nio'
require 'thread_safe'

module NSQ
  # Maintains a collection of subscribers to topics and channels.
  class Reader
    include NSQ::Util
    include NSQ::Logger

    attr_reader :selector, :options

    # Create a new NSQ Reader
    #
    # Options (Refer to NSQ::Subscriber::new for additional options which will be passed on to each subscriber):
    #   :nsqd_tcp_addresses [String or Array of Strings]
    #     Array of nsqd servers to connect to with port numbers
    #     ['server1:4150', 'server2:4150']
    #
    #   :logger [Logger]
    #     The Logger class
    #
    #   :logger_level [Symbol]
    #     The Logger Level [:info, :debug, :warn, :error]
    #
    def initialize(options={})
      @options            = options
      @nsqd_tcp_addresses = Array(options[:nsqd_tcp_addresses])

      logger          = options[:logger]       if options[:logger]
      logger.level    = options[:logger_level] if options[:logger_level]

      @selector    = ::NIO::Selector.new
      @timer       = Timer.new(@selector)
      @subscribers = ThreadSafe::Cache.new
      @stop        = Atomic.new(false)

      raise 'Must pass either option :nsqd_tcp_addresses' if @nsqd_tcp_addresses.empty?
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
      assert_topic_and_channel_valid(topic, channel)
      subscriber = nil
      name = "#{topic}:#{channel}"

      raise "Already subscribed to #{name}" if @subscribers[name]
      subscriber = @subscribers[name] = Subscriber.new(self, topic, channel, options, &block)

      @nsqd_tcp_addresses.each do |addr|
        address, port = addr.split(':')
        subscriber.add_connection(address, port.to_i)
      end

      subscriber
    end

    # Unsubscribe  a given topic and channel.
    def unsubscribe(topic, channel)
      name = "#{topic}:#{channel}"
      subscriber = @subscribers[name]
      return unless subscriber
      subscriber.stop
      @subscribers.delete(name)
    end

    def stopped?
      @stop.value
    end

    # Processes all the messages from the subscribed connections.  This will not return until #stop
    # has been called in a separate thread.
    def run
      until stopped? do
        @selector.select(@timer.next_interval) { |m| m.value.call }
      end
    end

    # Stop this reader which will gracefully exit the run method after all current messages are processed.
    def stop
      logger.debug("#{self}: Reader stopping...")
      @stop.try_update { |m| m = true }
      @selector.wakeup
      @subscribers.each_value(&:stop)
    rescue Atomic::ConcurrentUpdateError
      retry
    end

    # Call the given block from within the #run thread when the given interval has passed.
    def add_timeout(interval, &block)
      @timer.add(interval, &block)
    end
  end
end
