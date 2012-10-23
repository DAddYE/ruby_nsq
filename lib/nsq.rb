require 'nsq/loggable'
require 'nsq/reader'
require 'nsq/subscriber'
require 'nsq/connection'

module NSQ
  extend NSQ::Loggable

  MAGIC_V2 = "  V2"

  FRAME_TYPE_RESPONSE = 0
  FRAME_TYPE_ERROR    = 1
  FRAME_TYPE_MESSAGE  = 2

  def self.assert_topic_and_channel_valid(topic, channel)
    raise "Invalid topic #{topic}" unless valid_topic_name?(topic)
    raise "Invalid channel #{channel}" unless valid_channel_name?(channel)
  end

  def self.valid_topic_name?(topic)
    !!topic.match(/^[\.a-zA-Z0-9_-]+$/)
  end

  def self.valid_channel_name?(channel)
    !!channel.match(/^[\.a-zA-Z0-9_-]+(#ephemeral)?$/)
  end
end
