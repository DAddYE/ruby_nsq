# ruby_nsq

https://github.com/ClarityServices/ruby_nsq

## Description:

Ruby client for the [NSQ](https://github.com/bitly/nsq) realtime message processing system.

## Install:

  gem install ruby_nsq

## Usage:

See [examples](https://github.com/ClarityServices/ruby_nsq/tree/master/examples)

Simple example for synchronous message handling:
```
require 'nsq'

reader = NSQ.create_reader(:nsqd_tcp_addresses => '127.0.0.1:4150')
# Subscribe to topic=test channel=simple
reader.subscribe('test', 'simple') do |message|
  # If this block raises an exception, then the message will be requeued.
  puts "Read #{message.body}"
end
reader.run   # Doesn't return until reader.stop is called
puts 'Reader stopped'
```

NOTE: Not yet implemented!
Advanced example demonstrating asynchronous handling of messages on multiple threads:
```
require 'nsq'

foo_worker_count = 50
bar_worker_count = 30
baz_worker_count = 20

reader = NSQ.create_reader(:nsqd_tcp_addresses => '127.0.0.1:4150')

foo_queue  = reader.subscribe('test',  'foo', :max_in_flight => foo_worker_count)
bar_queue  = reader.subscribe('test2', 'bar', :max_in_flight => bar_worker_count)
baz_queue  = reader.subscribe('test2', 'baz', :max_in_flight => baz_worker_count)

foo_threads = foo_worker_count.times.map do |i|
  Thread.new(i) do |i|
    # API #1
    until foo_queue.stopped?
      message = foo_queue.read
      if message
        begin
          puts 'Foo[%02d] read: %s' % i, message.body
          sleep 1  # Dummy processing of message
          # Give success status so message won't be requeued
          message.success!
        rescue Exception => e
          # Message will be requeued
          message.failure!
        end
      end
    end

    # API #2 (Equivalent to above)
    foo_queue.run do |message|
      puts 'Foo[%02d] read: %s' % i, message.body
      sleep 1  # Dummy processing of message
    end

    puts 'Foo[%02d] thread exiting' % i
  end
end

bar_threads = ... Same kind of thing as above ...
baz_threads = ... Same kind of thing as above ...

reader.run   # Doesn't return until reader.stop is called
puts 'Reader stopped'
foo_threads.each(&:join)
bar_threads.each(&:join)
baz_threads.each(&:join)
```

## TODO:

* No block subscribe calls that will return queue

* Ready logic

* Backoff for connections and failed messages.
