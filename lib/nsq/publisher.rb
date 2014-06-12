require 'socket'
require 'nsq/error'

module NSQ
  class Publisher

    SIZE_BYTES = 4

    def initialize(host, port, options={}, &block)
      @socket = TCPSocket.open(host, port)
      @socket.write(MAGIC_V2)
      block[self] if block_given?
    ensure
      close if block_given?
    end

    def publish(topic, message)
      buf = ['PUB ', topic, "\n", message.length, message].pack('a*a*a*Na*')
      @socket.write(buf)

      response = ''
      have_received_ok = false
      loop do
        until response.size >= expected_size(response)
          response += @socket.recv(4096)
        end

        size = expected_size(response)

        # Extract the first message from `response`.
        first_message = response.slice!(0, size)
        _, _, data = first_message.unpack("NNa#{size}")
        have_received_ok ||= handle(data)

        # If the message was "OK", we can return successfully when the buffer
        # is empty.
        return if response.empty? && have_received_ok

        # We are now in a situation where we have processed a message, but we
        # must process more. Either it was an OK but we have partially read
        # another message that we must finish, or it was a heartbeat and we
        # must read again until we get an OK or an error code.
      end
    end

    def close
      @socket.close if @socket
    end

    private
    def expected_size(response)
      return 8 if response.size < 8
      SIZE_BYTES + response.unpack('N')[0]
    end

    def handle(msg)
      case msg
      when 'OK'            ; return true
      when '_heartbeat_'   ; return false
      when 'E_INVALID'     ; raise NSQ::Error::Invalid
      when 'E_BAD_TOPIC'   ; raise NSQ::Error::BadTopic
      when 'E_BAD_MESSAGE' ; raise NSQ::Error::BadMessage
      when 'E_PUT_FAILED'  ; raise NSQ::Error::PutFailed
      else raise NSQ::Error, "Unknown PUB response: #{msg}"
      end
    end

  end
end
