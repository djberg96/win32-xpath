require 'benchmark'
require 'xpath'

MAX = 100000

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

  x.report("expand_path('')") do
    str = ""
    MAX.times{ File.expand_path(str) }
  end

##############################################

  x.report("xpath('foo/bar')") do
    str = "foo/bar"
    MAX.times{ File.xpath(str) }
  end

  x.report("xpath('C:/foo/bar')") do
    str = "C:/foo/bar"
    MAX.times{ File.xpath(str) }
  end

  x.report("xpath('//foo/bar')") do
    str = "//foo/bar"
    MAX.times{ File.xpath(str) }
  end

  x.report("xpath('foo//bar///')") do
    str = "foo//bar///"
    MAX.times{ File.xpath(str) }
  end

  x.report("xpath('')") do
    str = ""
    MAX.times{ File.xpath(str) }
  end
end
