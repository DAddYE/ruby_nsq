require 'thread' #Mutex

module NSQ
  # An asynchronous subscriber that can be run on multiple threads for reading messages from a subscribed channel.
  class QueueSubscriber < Subscriber
    def initialize(reader, topic, channel, options) #:nodoc:
      super
      @queue     = Queue.new
      @run_mutex = Mutex.new
      @run_count = 0
    end

    def ready_count #:nodoc:
      # Return the minimum of Subscriber#ready_count and the amount of space left in the queue
      [super, self.max_in_flight - @queue.size].min
    end

    def handle_message(connection, message) #:nodoc:
      @queue << [connection, message]
    end

    # Processes messages from the subscribed connections.  This will not return until #stop
    # has been called in a separate thread.  This can be called from multiple threads if you
    # want multiple workers handling the incoming messages.
    def run(&block)
      @run_mutex.synchronize { @run_count += 1}
      until @stopped
        pair = @queue.pop
        if pair == :stop
          # Give the next thread something to pop
          @queue << :stop
          return
        end
        connection, message = pair
        process_message(connection, message, &block)
      end
    ensure
      @run_mutex.synchronize { @run_count -= 1}
    end

    # Stop this subscriber once all the queued messages have been handled.
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
