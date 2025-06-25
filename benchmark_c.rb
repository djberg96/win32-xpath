require 'benchmark'

# First, load our C extension version
require 'win32/xpath'

puts "Testing C extension performance..."

# Test data
test_paths = [
  'C:/temp',
  '~/Documents',
  './test',
  '',
  'C:',
  '/temp',
  'test/../other'
]

n = 10000

# Benchmark the C extension
result = Benchmark.bm(20) do |x|
  x.report("C Extension:") do
    n.times do
      test_paths.each do |path|
        File.expand_path(path) rescue nil
      end
    end
  end
end

puts "\nC extension benchmark completed!"
puts "Processed #{n * test_paths.length} path expansions"
