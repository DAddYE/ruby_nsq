require 'monitor'
require 'thread'  #Mutex

module NSQ
  class Connection
    attr_reader :name

    def initialize(reader, subscriber, host, port)
      @reader        = reader
      @subscriber    = subscriber
      @selector      = reader.selector
      @host          = host
      @port          = port
      @name          = "#{subscriber.name}:#{host}:#{port}"
      @write_monitor = Monitor.new
      @ready_mutex   = Mutex.new
      @sending_ready = false

      # Connect states :init, :interval, :connecting, :connected, :closed
      @connect_state = :init

      @next_connection_time     = nil
      @next_ready_time          = nil
      @connection_backoff_timer = nil
      @ready_backoff_timer      = @subscriber.create_ready_backoff_timer

      connect
    end

    def send_init(topic, channel, short_id, long_id)
      write NSQ::MAGIC_V2
      write "SUB #{topic} #{channel} #{short_id} #{long_id}\n"
      self.send_ready
    end

    def send_ready
      @ready_count = @subscriber.ready_count
      write "RDY #{@ready_count}\n" unless @subscriber.stopped?
      @sending_ready = false
    end

    def send_finish(id, success)
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

    def send_requeue(id, time_ms)
      write "REQ #{id} #{time_ms}\n"
      @ready_mutex.synchronize do
        @ready_count -= 1
        @ready_backoff_timer.failure
        check_ready
      end
    end

    def reset
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
          NSQ.logger.debug {"#{self}: Reattempting connection in #{interval} seconds"}
          @reader.add_timeout(interval) do
            connect
          end
        else
          connect
        end
      end
    end

    def close(permanent=true)
      NSQ.logger.debug {"#{@name}: Closing..."}
      @write_monitor.synchronize do
        begin
          @selector.deregister(@socket)
          # Use straight socket to write otherwise we need to use Monitor instead of Mutex
          @socket.write "CLS\n"
          @socket.close
        rescue Exception => e
        ensure
          @connect_state = permanent ? :closed : :init
          @socket        = nil
        end
      end
    end

    def connect
      return unless verify_connect_state?(:init, :interval)
      NSQ.logger.debug {"#{self}: Beginning connect"}
      @connect_state = :connecting
      @buffer        = ''
      @connecting    = false
      @connected     = false
      @ready_count   = 0
      @socket        = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      @sockaddr      = Socket.pack_sockaddr_in(@port, @host)
      @monitor       = @selector.register(@socket, :w)
      @monitor.value = proc { do_connect }
      do_connect
    end

    private

    def do_connect
      @write_monitor.synchronize do
        return unless verify_connect_state?(:connecting)
        begin
          @socket.connect_nonblock(@sockaddr)
          # Apparently we always throw an exception here
          NSQ.logger.debug {"#{self}: do_connect fell thru without throwing an exception"}
        rescue Errno::EINPROGRESS
          NSQ.logger.debug {"#{self}: do_connect - connect in progress"}
        rescue Errno::EISCONN
          NSQ.logger.debug {"#{self}: do_connect - connection complete"}
          @selector.deregister(@socket)
          monitor = @selector.register(@socket, :r)
          monitor.value = proc { read_messages }
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
          NSQ.logger.debug {"#{self}: Delaying READY for #{interval} seconds"}
          @sending_ready = true
          @reader.add_timeout(interval) do
            send_ready
          end
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
              @buffer = @buffer[(4+size)..-1]
            else
              NSQ.logger.error("I don't know what to do with the rest of this buffer: #{@buffer[8,size-4].inspect}") if @buffer.length > 8
              @buffer = @buffer[(4+size)..-1]
            end
          when NSQ::FRAME_TYPE_ERROR
            @subscriber.handle_frame_error(self, @buffer[8, size-4])
            @buffer = @buffer[(4+size)..-1]
          when NSQ::FRAME_TYPE_MESSAGE
            raise "Bad message: #{@buffer.inspect}" if size < 30
            ts_hi, ts_lo, attempts, id = @buffer.unpack('@8NNna16')
            body = @buffer[34, size-30]
            message = Message.new(self, id, ts_hi, ts_lo, attempts, body)
            @buffer = @buffer[(4+size)..-1]
            NSQ.logger.debug {"#{self}: Read message=#{message}"}
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
      NSQ.logger.debug {"#{@name}: Sending #{msg.inspect}"}
      # We should only ever have one reader but we can have multiple writers
      @write_monitor.synchronize do
        @socket.write(msg) if verify_connect_state?(:connected)
      end
    end

    def to_s
      @name
    end

    private

    def verify_connect_state?(*states)
      return true if states.include?(@connect_state)
      NSQ.logger.error("Unexpected connect state of #{@connect_state}, expected to be in #{states.inspect}\n\t#{caller[0]}")
      if @connect_state != :closed
        # Likely in a bug state.
        # I don't want to get in an endless loop of exceptions.  Is this a good idea or bad?  Maybe close to deregister first
        # Attempt recovery
        @connect_state = :init
        connect
      end
      return false
    end
  end
end
