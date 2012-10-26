require 'thread' #Mutex

module NSQ
  class QueueSubscriber < Subscriber
    def initialize(reader, topic, channel, options)
      super
      @queue     = Queue.new
      @run_mutex = Mutex.new
      @run_count = 0
    end

    def ready_count
      # Return the minimum of Subscriber#ready_count and the amount of space left in the queue
      [super, self.max_in_flight - @queue.size].min
    end

    def handle_message(connection, message)
      @queue << [connection, message]
    end

    def run(&block)
      @run_mutex.synchronize { @run_count += 1}
      until @stopped
        pair = @queue.pop
        if pair == :stop
          @queue << :stop
          return
        end
        connection, message = pair
        process_message(connection, message, &block)
      end
    ensure
      @run_mutex.synchronize { @run_count -= 1}
    end

    def stop
      @stopped = true
      # Give the threads something to pop
      @queue << :stop
      # TODO: Put a max time on this so we don't potentially hang
      sleep 1 while @run_count > 0
      super
    end
  end
end
