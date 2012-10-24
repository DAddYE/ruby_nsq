require 'socket'
require 'thread'
require 'monitor'
require 'nio'
#require 'thread_safe'

module NSQ
  class Reader
    attr_reader :name, :long_id, :short_id

    def initialize(options={})
      @options                = options
      @subscriber_class       = options[:subscriber_class]             || ::NSQ::Subscriber
      @poll_interval          = options[:poll_interval]                || 5
      @nsqd_tcp_addresses     = s_to_a(options[:nsqd_tcp_addresses])
      @lookupd_http_addresses = s_to_a(options[:lookupd_http_addresses])
      @lookupd_poll_interval  = options[:lookupd_poll_interval]        || 120
      @long_id                = options[:long_id]                      || Socket.gethostname
      @short_id               = options[:short_id]                     || @long_id.split('.')[0]
      NSQ.logger              = options[:logger] if options[:logger]
      NSQ.logger.level        = options[:logger_level] if options[:logger_level]

      @selector               = ::NIO::Selector.new
      @topic_count            = Hash.new(0)
      @subscribers            = {}
      @subscriber_mutex       = Monitor.new
      @name                   = "#{@long_id}:#{@short_id}"

      raise 'Must pass either option :nsqd_tcp_addresses or :lookupd_http_addresses' if @nsqd_tcp_addresses.empty? && @lookupd_http_addresses.empty?

      # TODO: If the messages are failing, the backoff timer will exponentially increase a timeout before sending a RDY
      #self.backoff_timer = dict((k, BackoffTimer.BackoffTimer(0, 120)) for k in self.task_lookup.keys())
        
      @conns = {}
      @last_lookup = nil

      @logger.info("starting reader for topic '%s'..." % self.topic) if @logger
    end

    def subscribe(topic, channel, subscribe_options={}, &block)
      NSQ.assert_topic_and_channel_valid(topic, channel)
      @topic     = topic
      @channel   = channel
      subscriber = nil
      name       = "#{topic}:#{channel}"
      @subscriber_mutex.synchronize do
        raise "Already subscribed to #{name}" if @subscribers[name]
        subscriber = @subscribers[name] = @subscriber_class.new(self, @selector, topic, channel, @options, subscribe_options, &block)
      end

      @nsqd_tcp_addresses.each do |addr|
        address, port = addr.split(':')
        subscriber.add_connection(address, port.to_i)
      end
      subscriber
    end

    def unsubscribe(topic, channel)
      name = "#{topic}:#{channel}"
      @subscriber_mutex.synchronize do
        subscriber = @subscribers[name]
        return unless subscriber
        subscriber.close
        @subscribers.delete(name)
      end
    end

    def run
      @stopped = false
      until @stopped do
        if (Time.now.to_i - @last_lookup.to_i) > @lookupd_poll_interval
          # Do lookupd
        end
        @selector.select(@poll_interval) { |m| m.value.call }
      end
    end

    def stop
      NSQ.logger.info("#{self}: Reader stopping...")
      @stopped = true
      @selector.wakeup
      @subscriber_mutex.synchronize do
        @subscribers.each_value {|subscriber| subscriber.close}
      end
    end

    def to_s
      @name
    end

    def s_to_a(val)
      val.kind_of?(String) ? [val] : val
    end
  end
end
