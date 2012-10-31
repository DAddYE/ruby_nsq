require 'socket'

module NSQ
  class Publisher
    def initialize(host, port, options={}, &block)
      @socket = TCPSocket.open(host, port)
      @socket.write(MAGIC_V2)
      @response_timeout = options[:response_timeout] || 5
      yield self if block_given?
    ensure
      close if block_given?
    end

    def publish(topic, message)
      buf = ['PUB ', topic, "\n", message.length, message].pack('a*a*a*Na*')
      @socket.write(buf)
      response = ''
      loop do
        response += @socket.recv(4096)
        size, frame, msg = response.unpack('NNa*')
        if response.length == size+4
          case msg
            when 'OK' then return
            when 'E_INVALID'     then raise 'Invalid message'
            when 'E_BAD_TOPIC'   then raise 'Bad topic'
            when 'E_BAD_MESSAGE' then raise 'Bad message'
            when 'E_PUT_FAILED'  then raise 'Put failed'
            else raise "Unknown PUB response: #{msg}"
          end
        elsif response.length > size+4
          raise "Unexpected PUB response - Expected size = #{size} actual size = #{response.length-4}: message=#{msg}"
        end
      end
    end

    def close
      @socket.close
    end
  end
end
