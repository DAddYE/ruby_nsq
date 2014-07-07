require 'logger'

module NSQ
  module Logger
    def logger
      @_logger ||= 
        begin
          l = ::Logger.new(STDOUT)
          l.level = ::Logger::INFO
          l
        end
    end

    def logger=(logger)
      @_logger = logger
    end
  end
end
