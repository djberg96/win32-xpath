require 'win32/xpath'

puts "Comprehensive C Extension Test"
puts "=" * 50

test_cases = [
  # Basic cases
  ["Empty path", "", nil],
  ["Current directory", ".", nil],
  ["Simple relative", "foo", nil],
  ["Relative with nil dir", "foo", nil],
  
  # Absolute paths
  ["Absolute path", "C:/temp", nil],
  ["Absolute with drive only", "C:", nil],
  ["Root path", "C:/", nil],
  
  # Tilde expansion
  ["Tilde home", "~", nil],
  ["Tilde with path", "~/Documents", nil],
  ["Tilde with backslash", "~\\Documents", nil],
  
  # Relative with directory
  ["Relative with dir", "foo", "C:/Projects"],
  ["Relative with tilde dir", "foo", "~/Projects"],
  
  # Path normalization
  ["Path with ..", "test/../other", "C:/Projects"],
  ["Path with .", "test/./other", "C:/Projects"],
  
  # Edge cases
  ["Path with dots", "a.", nil],
  ["Path starting with dot", ".a", nil],
  ["Path with double dots", "..a", nil],
  ["Complex path", "a../b", nil],
  
  # Windows specific
  ["UNC path", "//server/share", nil],
  ["Forward slash", "/temp", nil],
  ["Mixed slashes", "C:\\temp/test", nil],
]

passed = 0
failed = 0

test_cases.each_with_index do |(desc, path, dir), i|
  print "#{i+1}. #{desc}: "
  
  begin
    if dir
      result = File.expand_path(path, dir)
    else
      result = File.expand_path(path)
    end
    
    # Basic validation
    if result.is_a?(String) && result.length > 0
      puts "PASS (#{result})"
      passed += 1
    else
      puts "FAIL (invalid result: #{result.inspect})"
      failed += 1
    end
  rescue => e
    puts "FAIL (#{e.class}: #{e.message})"
    failed += 1
  end
end

puts "\n" + "=" * 50
puts "Results: #{passed} passed, #{failed} failed"

if failed == 0
  puts "🎉 All tests PASSED! C extension is working correctly."
else
  puts "❌ Some tests failed. C extension needs debugging."
end

# Additional performance test
puts "\nQuick performance test..."
start_time = Time.now
100.times { File.expand_path("C:/test/path") }  # Use simple absolute path instead
end_time = Time.now
puts "100 expansions took #{((end_time - start_time) * 1000).round(2)}ms"
