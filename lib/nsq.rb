require 'nsq/loggable'
require 'nsq/message'
require 'nsq/reader'
require 'nsq/subscriber'
require 'nsq/publisher'
require 'nsq/queue_subscriber'
require 'nsq/connection'
require 'nsq/backoff_timer'
require 'nsq/timer'
require 'nsq/util'

module NSQ
  extend NSQ::Loggable

  MAGIC_V2 = "  V2"

  FRAME_TYPE_RESPONSE = 0
  FRAME_TYPE_ERROR    = 1
  FRAME_TYPE_MESSAGE  = 2
end
