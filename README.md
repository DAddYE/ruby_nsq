# ruby_nsq

https://github.com/ClarityServices/ruby_nsq

## Description

Ruby client for the [NSQ](https://github.com/bitly/nsq) realtime message processing system.

## Install

  gem install ruby_nsq

## Usage

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

Advanced example demonstrating asynchronous handling of messages on multiple threads:
```
require 'nsq'

foo_worker_count = 50
bar_worker_count = 30
baz_worker_count = 20

reader = NSQ.create_reader(:nsqd_tcp_addresses => '127.0.0.1:4150')

foo_subscriber  = reader.subscribe('test',  'foo', :max_in_flight => foo_worker_count)
bar_subscriber  = reader.subscribe('test2', 'bar', :max_in_flight => bar_worker_count)
baz_subscriber  = reader.subscribe('test2', 'baz', :max_in_flight => baz_worker_count)

foo_threads = foo_worker_count.times.map do |i|
  Thread.new(i) do |i|
    foo_subscriber.run do |message|
      puts 'Foo[%02d] read: %s' % i, message.body
      sleep rand(10)  # Dummy processing of message
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

## TODO

* Implement lookupd

* Tests!

* Documentation

## Meta

* Code: `git clone git://github.com/ClarityServices/ruby_nsq.git`
* Home: <https://github.com/ClarityServices/ruby_nsq>
* Bugs: <http://github.com/reidmorrison/ruby_nsq/issues>
* Gems: <http://rubygems.org/gems/ruby_nsq>

This project uses [Semantic Versioning](http://semver.org/).

## Authors

Brad Pardee :: bradpardee@gmail.com
