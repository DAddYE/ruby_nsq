require 'nsq'
require 'thread'

x_worker_count = 50
y_worker_count = 30
z_worker_count = 20

puts 'Press enter to start and enter to finish'
$stdin.gets

reader         = NSQ.create_reader(:nsqd_tcp_addresses => '127.0.0.1:4150')

x_subscriber   = reader.subscribe('test_xy', 'x', :max_in_flight => x_worker_count)
y_subscriber   = reader.subscribe('test_xy', 'y', :max_in_flight => y_worker_count)
z_subscriber   = reader.subscribe('test_z',  'z', :max_in_flight => z_worker_count)

class MyThread < Thread
  attr_accessor :message_count
  def initialize(index, subscriber, char)
    @index = index
    super do |i, subscriber, char|
      @message_count = 0
      subscriber.run do |message|
        eval message.body
        print char
        @message_count += 1
      end
      print char.upcase
    end
  end
end

threads = {}
[[x_subscriber, x_worker_count, 'x'], [y_subscriber, y_worker_count, 'y'], [z_subscriber, z_worker_count, 'z']].each do |subscriber, count, char|
  threads[char] = count.times.map do |i|
    MyThread.new(i, subscriber, char)
  end
end

main_thread = Thread.new do
  reader.run
end
$stdin.gets
puts 'Exiting...'
reader.stop
main_thread.join
threads.each_value { |arr| arr.each(&:join) }
puts
puts "Summary of worker message counts"
threads.each do |char, arr|
  puts "#{char} -  #{arr.map(&:message_count).join(' ')}"
end
