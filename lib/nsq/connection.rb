require 'monitor'
require 'thread'  #Mutex

module NSQ
  # Represents a single subscribed connection to an nsqd server.
  class Connection
    include NSQ::Logger

    def initialize(reader, subscriber, host, port)
      @reader        = reader
      @subscriber    = subscriber
      @selector      = reader.selector
      @host          = host
      @port          = port
      @write_monitor = Monitor.new
      @ready_mutex   = Mutex.new
      @sending_ready = false

      # Connect states :init, :interval, :connecting, :connected, :closed
      @connect_state = :init

      @connection_backoff_timer = nil
      @ready_backoff_timer      = @subscriber.create_ready_backoff_timer

      connect
    end

    def send_init(topic, channel) #:nodoc:
      write NSQ::MAGIC_V2
      write "SUB #{topic} #{channel}\n"
      send_ready
    end

    def send_ready #:nodoc:
      @ready_count = @subscriber.ready_count
      write "RDY #{@ready_count}\n" unless @subscriber.stopped?
      @sending_ready = false
    end

    def send_finish(id, success) #:nodoc:
      write "FIN #{id}\n"
      @ready_mutex.synchronize do
        @ready_count -= 1
        if success
          @ready_backoff_timer.success
        else
          @ready_backoff_timer.failure
        end
        check_ready
      end
    end

    def send_requeue(id, time_ms) #:nodoc:
      write "REQ #{id} #{time_ms}\n"
      @ready_mutex.synchronize do
        @ready_count -= 1
        @ready_backoff_timer.failure
        check_ready
      end
    end

    def reset #:nodoc:
      return unless verify_connect_state?(:connecting, :connected)
      # Close with the hopes of re-establishing
      close(false)
      @write_monitor.synchronize do
        return unless verify_connect_state?(:init)
        @connection_backoff_timer ||= @subscriber.create_connection_backoff_timer
        @connection_backoff_timer.failure
        interval = @connection_backoff_timer.interval
        if interval > 0
          @connect_state = :interval
          logger.debug("Reattempting connection in #{interval} seconds")
          @reader.add_timeout(interval, &method(:connect))
        else
          connect
        end
      end
    end

    def close(permanent=true) #:nodoc:
      logger.debug "Closing..."
      @write_monitor.synchronize do
        begin
          @selector.deregister(@socket)
          # Use straight socket to write otherwise we need to use Monitor instead of Mutex
          @socket.write "CLS\n"
          @socket.close
        rescue Exception
        ensure
          @connect_state = permanent ? :closed : :init
          @socket        = nil
        end
      end
    end

    def connect #:nodoc:
      return unless verify_connect_state?(:init, :interval)
      logger.debug {"#{self}: Beginning connect"}
      @connect_state = :connecting
      @buffer        = ''
      @ready_count   = 0
      @socket        = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      @sockaddr      = Socket.pack_sockaddr_in(@port, @host)
      @socket.set_encoding 'UTF-8'
      @monitor       = @selector.register(@socket, :w)
      @monitor.value = method(:do_connect)
      do_connect
    end

    private

    def do_connect
      @write_monitor.synchronize do
        return unless verify_connect_state?(:connecting)
        begin
          @socket.connect_nonblock(@sockaddr)
          # Apparently we always throw an exception here
          logger.debug {"#{self}: do_connect fell thru without throwing an exception"}
        rescue Errno::EINPROGRESS
          logger.debug {"#{self}: do_connect - connect in progress"}
        rescue Errno::EISCONN
          logger.debug {"#{self}: do_connect - connection complete"}
          @selector.deregister(@socket)
          monitor = @selector.register(@socket, :r)
          monitor.value = method(:read_messages)
          @connect_state = :connected
          # The assumption for connections is that a good connection means the server is good, no ramping back up like ready counts
          @connection_backoff_timer = nil
          @subscriber.handle_connection(self)
        rescue SystemCallError => e
          @subscriber.handle_io_error(self, e)
        end
      end
    end

    def check_ready
      if !@sending_ready && @ready_count <= @subscriber.ready_threshold
        interval = @ready_backoff_timer.interval
        if interval == 0.0
          send_ready
        else
          logger.debug {"#{self}: Delaying READY for #{interval} seconds"}
          @sending_ready = true
          @reader.add_timeout(interval, method(:send_ready))
        end
      end
    end

    def read_messages
      @buffer << @socket.read_nonblock(4096)
      while @buffer.length >= 8
        size, frame = @buffer.unpack('NN')
        break if @buffer.length < 4+size
 
        case frame
        when NSQ::FRAME_TYPE_RESPONSE
          if @buffer[8,11] == "_heartbeat_"
            send_nop
            @subscriber.handle_heartbeat(self)
          elsif @buffer[8, 2] != "OK"
            logger.error("I don't know what to do with the rest of this buffer: #{@buffer[8,size-4].inspect}") if @buffer.length > 8
          end
          @buffer = @buffer[(4+size)..-1]
        when NSQ::FRAME_TYPE_ERROR
          @subscriber.handle_frame_error(self, @buffer[8, size-4])
          @buffer = @buffer[(4+size)..-1]
        when NSQ::FRAME_TYPE_MESSAGE
          raise "Bad message: #{@buffer.inspect}" if size < 30
          ts_hi, ts_lo, attempts, id = @buffer.unpack('@8NNna16')
          body = @buffer[34, size-30].force_encoding('UTF-8')
          message = Message.new(self, id, ts_hi, ts_lo, attempts, body)
          @buffer = @buffer[(4+size)..-1]
          logger.debug("Read message=#{message}")
          @subscriber.handle_message(self, message)
        else
          raise "Unrecognized message frame: #{frame} buffer=#{@buffer.inspect}"
        end
      end
    rescue Exception => e
      @subscriber.handle_io_error(self, e)
    end

    def send_nop
      write "NOP\n"
    end

    def write(msg)
      logger.debug("Sending #{msg.inspect}")
      # We should only ever have one reader but we can have multiple writers
      @write_monitor.synchronize do
        @socket.write(msg) if verify_connect_state?(:connected)
      end
    end

    def verify_connect_state?(*states)
      states.include?(@connect_state)
    end
  end
end
