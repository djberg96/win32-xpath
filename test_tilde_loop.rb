require 'win32/xpath'

puts "Testing tilde expansion in a loop..."

begin
  10.times do |i|
    result = File.expand_path("~/test/path")
    puts "#{i}: #{result}" if i < 3  # Only print first few
  end
  puts "10 iterations successful"
  
  100.times do |i|
    File.expand_path("~/test/path")
  end
  puts "100 iterations successful"
  
  1000.times do |i|
    File.expand_path("~/test/path")
  end
  puts "1000 iterations successful"
  
rescue => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.join("\n")
end

puts "Test completed."
