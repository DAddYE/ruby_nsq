require 'nsq'
require 'logger'

puts 'Press enter to start and enter to finish'
gets
reader = NSQ.create_reader(
    :nsqd_tcp_addresses => '127.0.0.1:4150',
    :logger_level       => Logger::DEBUG
)
thread = Thread.new do
  reader.subscribe('test', 'simple') do |message|
    puts "Read #{message.body}"
  end
  reader.run
  puts 'Reader exiting'
end
gets
reader.stop
thread.join
