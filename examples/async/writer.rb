if ARGV.length != 3
  $stderr.puts "ruby writer.rb <topic> <count> <eval-string>"
  $stderr.puts "  where <topic> is either test_xy or test_z"
  $stderr.puts "  and <eval-string> could be something like 'sleep rand(100)/10.0'"
  $stderr.puts "  Example: ruby writer.rb test_xy 500 'sleep rand(100)/10.0'"
  exit 1
end
topic       = ARGV[0]
count       = ARGV[1].to_i
eval_string = ARGV[2]
# TODO: Figure out TCP protocol
count.times do
  system "curl -d #{eval_string.inspect} 'http://127.0.0.1:4151/put?topic=#{topic}'"
end
