#!/usr/bin/env ruby

# Test script to verify the C extension works
require_relative 'lib/win32/xpath'

puts "Testing C extension..."

# Test basic path expansion
test_paths = [
  ["C:\\Users", nil],
  ["./test", "C:\\Projects"],
  ["~", nil],
  ["~/Documents", nil],
  ["", nil],
  ["test/../other", "C:\\Projects"],
  ["C:", nil],
  ["C:/", nil],
  ["/temp", nil]
]

test_paths.each do |path, dir|
  begin
    if dir
      result = File.expand_path(path, dir)
      puts "File.expand_path(#{path.inspect}, #{dir.inspect}) = #{result.inspect}"
    else
      result = File.expand_path(path)
      puts "File.expand_path(#{path.inspect}) = #{result.inspect}"
    end
  rescue => e
    puts "ERROR: File.expand_path(#{path.inspect}#{dir ? ", #{dir.inspect}" : ""}) => #{e.class}: #{e.message}"
  end
end

puts "\nC extension test completed."
