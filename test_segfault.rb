require 'win32/xpath'

puts "Testing specific segfault case..."

begin
  result = File.expand_path('../a', "C:/Temp/xxx")
  puts "SUCCESS: File.expand_path('../a', 'C:/Temp/xxx') = #{result}"
rescue => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.join("\n")
end

puts "Test completed."
