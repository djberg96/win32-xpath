require 'win32/xpath'

puts "Testing if C extension loaded..."

# Check if we can access the expand_path method
begin
  result = File.expand_path("C:/temp")
  puts "expand_path works: #{result}"
  
  # Test a few critical cases
  puts "Empty path: #{File.expand_path('')}"
  puts "Tilde: #{File.expand_path('~')}"
  puts "Relative: #{File.expand_path('test')}"
  
  puts "C extension appears to be working correctly!"
rescue => e
  puts "Error: #{e.class}: #{e.message}"
  puts e.backtrace.join("\n")
end
