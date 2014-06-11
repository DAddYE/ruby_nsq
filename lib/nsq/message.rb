module NSQ
  class Message
    attr_reader :connection, :id, :attempts, :body

    def initialize(connection, id, timestamp_high, timestamp_low, attempts, body)
      @connection     = connection
      @id             = id
      @timestamp_low  = timestamp_low
      @attempts       = attempts
      @body           = body
    end

    def timestamp
      # TODO: Not really a nanosecond timestamp
      #Time.at((@timestamp_high * 2**32 + @timestamp_low) / 1000000000.0)
      Time.at(@timestamp_low)
    end

    def to_s
      "#{connection} id=#{id} timestamp=#{timestamp} attempts=#{attempts} body=#{body}"
    end
  end
end
