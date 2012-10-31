module NSQ
  module Util

    def self.assert_topic_and_channel_valid(topic, channel) #:nodoc:
      raise "Invalid topic #{topic}" unless valid_topic_name?(topic)
      raise "Invalid channel #{channel}" unless valid_channel_name?(channel)
    end

    def self.valid_topic_name?(topic) #:nodoc:
      !!topic.match(/^[\.a-zA-Z0-9_-]+$/)
    end

    def self.valid_channel_name?(channel) #:nodoc:
      !!channel.match(/^[\.a-zA-Z0-9_-]+(#ephemeral)?$/)
    end
  end
end
