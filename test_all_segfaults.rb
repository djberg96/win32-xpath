require 'win32/xpath'

# Test cases that could potentially segfault
test_cases = [
  # The original failing case from line 60
  ["../a", "C:/Temp/xxx"],
  
  # Other potential edge cases
  [".", "C:/Temp"],
  ["..", "C:/Temp/subdir"],
  ["../", "C:/Temp/subdir"],
  ["../../test", "C:/Temp/sub1/sub2"],
  ["", "C:/Temp"],
  
  # Tilde cases
  ["~", nil],
  ["~/test", nil],
  
  # Mixed cases
  ["../test", "~/Projects"],
  [".", "~/"],
]

puts "Testing potential segfault cases..."

test_cases.each_with_index do |(path, dir), i|
  begin
    if dir
      result = File.expand_path(path, dir)
      puts "#{i+1}. File.expand_path(#{path.inspect}, #{dir.inspect}) = #{result}"
    else
      result = File.expand_path(path)
      puts "#{i+1}. File.expand_path(#{path.inspect}) = #{result}"
    end
  rescue => e
    puts "#{i+1}. ERROR: #{e.class}: #{e.message}"
  end
end

puts "\nAll segfault tests completed successfully!"
