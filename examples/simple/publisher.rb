#!/usr/bin/env ruby

require 'nsq'

if ARGV.length == 0
  $stderr.puts "bundle exec ./publisher.rb <message>*"
  $stderr.puts "  Example: bundle exec ./publisher.rb hello world"
  exit 1
end

NSQ::Publisher.new('localhost', 4150) do |publisher|
  publisher.publish('test', ARGV.join(' '))
end
