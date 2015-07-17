Gem::Specification.new do |s|
  s.name = 'solanum'
  s.version = '0.2.0'
  s.author = 'Greg Look'
  s.email = 'greg@greg-look.net'
  s.homepage = 'https://github.com/greglook/solanum'
  s.platform = Gem::Platform::RUBY
  s.summary = 'DSL for custom monitoring configuration'
  s.license = 'Public Domain'

  s.add_dependency 'riemann-client', '>= 0.2.2'

  s.files = Dir['lib/**/*', 'bin/*', 'README.md'].to_a
  s.bindir = 'bin'
  s.executables << 'solanum'
  s.require_path = 'lib'

  s.required_ruby_version = '>= 1.9.1'
end
