#!/usr/bin/env ruby

require 'nsq'
require 'logger'

# Cntl-c doesn't run at_exit under jruby
puts 'Press enter to start and enter to finish'
gets
reader = NSQ.create_reader(
    :nsqd_tcp_addresses => '127.0.0.1:4150',
    #:logger_level       => Logger::DEBUG
)
thread = Thread.new do
  begin
    reader.subscribe('test', 'simple') do |message|
      puts "Read #{message.body}"
    end
    reader.run
  rescue Exception => e
    $stderr.puts "Unexpected error: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
  end
  puts 'Reader exiting'
end
at_exit {
  reader.stop
  thread.join
}
gets
