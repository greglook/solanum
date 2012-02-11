# Rake tasks to build project.
#
# Author:: Greg Look

# Validates the syntax of all Ruby source files
task :syntax do
  files = Dir['bin/*', 'lib/**/*.rb']

  valid = true
  puts "Checking Ruby file syntax..."
  files.each do |file|
    output = %x{ruby -c #{file}}
    if $?.success?
      puts " PASS  #{file}"
    else
      puts " FAIL  #{file}"
      puts output
      valid = false
    end
  end
  valid
end

task :default => :syntax
