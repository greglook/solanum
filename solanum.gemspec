Gem::Specification.new do |s|
  s.name = 'solanum'
  s.version = '0.8.0'
  s.author = 'Greg Look'
  s.email = 'greg@greglook.net'
  s.homepage = 'https://github.com/greglook/solanum'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Extensible monitoring daemon'
  s.license = 'Public Domain'

  s.add_dependency 'riemann-client', '>= 0.2.2'

  s.files = Dir['lib/**/*', 'bin/*', 'README.md'].to_a
  s.bindir = 'bin'
  s.executables << 'solanum'
  s.require_path = 'lib'

  s.required_ruby_version = '>= 1.9.1'
end
