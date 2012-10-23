require 'nsq'

reader = NSQ::Reader.new(:nsqd_tcp_addresses => '127.0.0.1:4150')
reader.subscribe('test', 'simple') do |id, timestamp, attempts, body|
  puts "id=#{id} ts=#{timestamp} attempts=#{attempts} body=#{body}"
end
at_exit { reader.stop }
reader.run
