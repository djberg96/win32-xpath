require 'benchmark'

MAX = 400000
puts "\nOld File.expand_path"

Benchmark.bm(30) do |x|
  x.report("expand_path('foo/bar')") do
    str = "foo/bar"
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('C:/foo/bar')") do
    str = "C:/foo/bar"
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('//foo/bar')") do
    str = "//foo/bar"
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('foo//bar///')") do
    str = "foo//bar///"
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('~')") do
    str = "~"
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('')") do
    str = ""
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('.')") do
    str = "."
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('', '~')") do
    MAX.times{ File.expand_path('', '~') }
  end
end

require 'win32/xpath'
puts "\nNew File.expand_path\n"

Benchmark.bm(30) do |x|
  x.report("expand_path('foo/bar')") do
    str = "foo/bar"
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('C:/foo/bar')") do
    str = "C:/foo/bar"
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('//foo/bar')") do
    str = "//foo/bar"
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('foo//bar///')") do
    str = "foo//bar///"
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('~')") do
    str = "~"
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('')") do
    str = ""
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('.')") do
    str = "."
    MAX.times{ File.expand_path(str) }
  end

  x.report("expand_path('', '~')") do
    MAX.times{ File.expand_path('', '~') }
  end
end
