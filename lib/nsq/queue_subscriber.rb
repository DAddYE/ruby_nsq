module NSQ
  class QueueSubscriber < Subscriber
    def initialize(reader, topic, channel, options)
      super
      @queue = Queue.new
    end

    def handle_message(connection, message)
      @queue << [connection, message]
    end

    def run(&block)
      until @stopped
        pair = @queue.pop
        if pair == :stop
          @queue << :stop
          return
        end
        connection, message = pair
        process_message(connection, message, &block)
      end
    end

    def stop
      super
      # Give the threads something to popd
      @queue << :stop
    end
  end
end
