Gem::Specification.new do |s|
  s.name        = 'ruby_nsq'
  s.version     = '0.0.1'
  s.summary     = 'Ruby client for NSQ'
  s.description = 'Ruby client for NSQ modeled after pynsq'
  s.authors     = ['Brad Pardee']
  s.email       = ['bradpardee@gmail.com']
  s.homepage    = 'http://github.com/ClarityServices/ruby_nsq'
  s.files       = Dir["{lib}/**/*"] + %w(LICENSE.txt Rakefile History.md README.md)
  s.test_files  = Dir["test/**/*"]

  s.add_dependency 'resilient_socket'
  s.add_dependency 'nio4r'
  s.add_dependency 'http_parser.rb'
  s.add_dependency 'thread_safe'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'turn'
  s.add_development_dependency 'wirble'
  s.add_development_dependency 'hirb'
end
