require 'nsq/loggable'
require 'nsq/message'
require 'nsq/reader'
require 'nsq/subscriber'
require 'nsq/queue_subscriber'
require 'nsq/connection'
require 'nsq/backoff_timer'
require 'nsq/timer'

module NSQ
  extend NSQ::Loggable

  MAGIC_V2 = "  V2"

  FRAME_TYPE_RESPONSE = 0
  FRAME_TYPE_ERROR    = 1
  FRAME_TYPE_MESSAGE  = 2

  # Create a NSQ::Reader used for subscribing to topics and channels.
  # Refer to NSQ::Reader::new for available options.
  def self.create_reader(options, &block)
    Reader.new(options, &block)
  end


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
