# Ruby NSQ

Ruby client for the [NSQ](https://github.com/bitly/nsq) realtime message processing system.

## Install

  gem install ruby_nsq

## Usage

See [examples](https://github.com/ClarityServices/ruby_nsq/tree/master/examples)

Simple example for synchronous message handling:

```rb
require 'nsq'

reader = NSQ::Reader.new(nsqd_tcp_addresses: '127.0.0.1:4150')
# Subscribe to topic=test channel=simple
reader.subscribe('test', 'simple') do |message|
  # If this block raises an exception, then the message will be requeued.
  puts "Read #{message.body}"
end
reader.run   # Doesn't return until reader.stop is called
puts 'Reader stopped'
```

Advanced example demonstrating asynchronous handling of messages on multiple threads:

```rb
require 'nsq'

foo_worker_count = 50
bar_worker_count = 30
baz_worker_count = 20

reader = NSQ::Reader.new(nsqd_tcp_addresses: '127.0.0.1:4150')

foo_subscriber  = reader.subscribe('test',  'foo', max_in_flight: foo_worker_count)
bar_subscriber  = reader.subscribe('test2', 'bar', max_in_flight: bar_worker_count)
baz_subscriber  = reader.subscribe('test2', 'baz', max_in_flight: baz_worker_count)

foo_threads = foo_worker_count.times.map do |i|
  Thread.new(i) do |i|
    foo_subscriber.run do |message|
      puts 'Foo[%02d] read: %s' % i, message.body
      sleep rand(10)  # Dummy processing of message
    end
    puts 'Foo[%02d] thread exiting' % i
  end
end

# bar_threads = ... Same kind of thing as above ...
# baz_threads = ... Same kind of thing as above ...

reader.run   # Doesn't return until reader.stop is called
puts 'Reader stopped'
foo_threads.each(&:join)
bar_threads.each(&:join)
baz_threads.each(&:join)
```

## TODO

* Implement lookupd
* Tests!
* Support IPv6

## Meta

* Code: `git clone git://github.com/daddye/ruby_nsq.git`
* Home: <https://github.com/daddye/ruby_nsq>
* Bugs: <http://github.com/daddye/ruby_nsq/issues>
* Gems: <http://rubygems.org/gems/ruby_nsq>

This project uses [Semantic Versioning](http://semver.org/).

## Authors

* Brad Pardee :: bradpardee@gmail.com
* Davide D'Agostino (@DAddYE) :: info@daddye.it

## LICENSE

Copyright (C) 2014

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
