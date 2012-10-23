module NSQ
  class Connection
    attr_reader :name

    def initialize(subscriber, selector, host, port)
      @subscriber    = subscriber
      @selector      = selector
      @host          = host
      @port          = port
      @name          = "#{subscriber.name}:#{host}:#{port}"
      connect
    end

    def send_init(topic, channel, short_id, long_id, ready_count)
      write(NSQ::MAGIC_V2)
      write "SUB #{topic} #{channel} #{short_id} #{long_id}\n"
      self.send_ready(ready_count)
    end

    def send_ready(count)
      @ready_count += count
      write "RDY #{count}\n"
    end

    def send_finish(id)
      write "FIN #{id}\n"
    end

    def send_requeue(id, time_ms)
      write "REQ #{id} #{time_ms}\n"
    end

    def close
      @selector.deregister(@socket)
      write "CLS\n"
      @socket.close
    rescue
    ensure
      @socket = nil
    end

    def connect
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
      @socket.connect_nonblock(@sockaddr)
      puts 'Holy ugly API, Batman!'
    rescue Errno::EINPROGRESS
      @connecting = true
    rescue Errno::EISCONN
      @selector.deregister(@socket)
      monitor = @selector.register(@socket, :r)
      monitor.value = proc { read_messages }
      @subscriber.handle_connection(self)
      @connecting = false
      @connected  = true
    rescue SystemCallError => e
      @subscriber.handle_io_error(self, e)
    end

    def read_messages
      NSQ.logger.debug("Before read buffer=#{@buffer.inspect}")
      @buffer << @socket.read_nonblock(4096)
      NSQ.logger.debug("After read buffer=#{@buffer.inspect}")
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
            raise "Bad message: #{@buffer.inspect}" if size < 34
            ts_hi, ts_lo, attempts, id = @buffer.unpack('@8NNna16')
            timestamp = Time.at((ts_hi * 2**32 + ts_lo) / 1000000000.0)
            body = @buffer[34, size-30]
            @buffer = @buffer[(4+size)..-1]
            @subscriber.handle_message(self, id, timestamp, attempts, body)
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
      @socket.write(msg)
    end
  end
end
