require 'benchmark'
require_relative 'lib/win32/xpath'

# Benchmark script to test performance improvements

test_paths = [
  '.',
  '..',
  'foo',
  'foo/bar',
  'C:/',
  'C:/temp',
  '~',
  '~/documents',
  'a' * 100,  # Long path
  '../test/path'
]

puts "Benchmarking File.expand_path performance with #{test_paths.length} different path types"
puts "Running 1000 iterations per test case..."
puts

iterations = 1000

Benchmark.bm(25) do |x|
  test_paths.each do |path|
    x.report("expand_path('#{path.length > 20 ? path[0..17] + '...' : path}')") do
      iterations.times { File.expand_path(path) }
    end
  end
  
  # Test with directory argument
  x.report("expand_path with dir arg") do
    iterations.times { File.expand_path('foo', 'C:/temp') }
  end
  
  # Test tilde expansion
  x.report("tilde expansion") do
    iterations.times { File.expand_path('~/test') }
  end
  
  # Test very long paths
  x.report("very long paths") do
    100.times { File.expand_path('a' * 500) }
  end
end

puts "\nOptimizations implemented:"
puts "1. Cached environment variable lookups"
puts "2. Pre-compiled regex patterns"
puts "3. Reusable memory buffers"
puts "4. Optimized string operations (tr!, chop!, etc.)"
puts "5. Fast-path for common operations"
puts "6. Reduced FFI overhead"
puts "7. Single-pass string processing"
