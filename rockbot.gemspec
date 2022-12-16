Gem::Specification.new do |s|
  s.name        = "rockbot"
  s.version     = "1.1.1"
  s.summary     = "Extensible IRC bot"
  s.authors     = ["David McMackins II"]
  s.files       = Dir["lib/**/*.rb", "bin/*"]
  s.homepage    = "https://github.com/2mac/rockbot"
  s.license     = "COIL-1.0"

  s.add_runtime_dependency 'sqlite3', '~> 1'
  s.add_runtime_dependency 'sequel', '~> 5'

  s.executables << 'rockbot'
end
