Gem::Specification.new do |s|
  s.name        = 'ruby_nsq'
  s.version     = '0.0.3'
  s.summary     = 'Ruby client for NSQ'
  s.description = 'Ruby client for the NSQ realtime message processing system'
  s.authors     = ['Brad Pardee', "DAddYE (Davide D'Agostino)"]
  s.email       = ['bradpardee@gmail.com', 'info@daddye.it']
  s.homepage    = 'https://github.com/bpardee/ruby_nsq.git'
  s.files       = Dir["{lib,examples}/**/*"] + %w(LICENSE.txt Rakefile History.md README.md)
  s.test_files  = Dir["test/**/*"]

  s.add_dependency 'nio4r'
  s.add_dependency 'thread_safe'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'turn'
  s.add_development_dependency 'wirble'
  s.add_development_dependency 'hirb'
end
