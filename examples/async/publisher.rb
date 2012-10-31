#!/usr/bin/env ruby

require 'nsq'

if ARGV.length != 3
  $stderr.puts "bundle exec ./publisher.rb <topic> <count> <eval-string>"
  $stderr.puts "  where <topic> is either test_xy or test_z"
  $stderr.puts "  and <eval-string> could be something like 'sleep rand(100)/10.0'"
  $stderr.puts "  Example: bundle exec ./publisher.rb test_xy 500 'sleep rand(100)/10.0'"
  $stderr.puts "       or: bundle exec ./publisher.rb test_z 5000 nil"
  exit 1
end
topic       = ARGV[0]
count       = ARGV[1].to_i
eval_string = ARGV[2]

NSQ::Publisher.new('localhost', 4150) do |publisher|
  count.times do
    publisher.publish(topic, eval_string)
  end
end
