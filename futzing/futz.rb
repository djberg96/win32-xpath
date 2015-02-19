require 'xpath'
require 'tmpdir'

path = "../a"
tmp = Dir.tmpdir

#p path
#p tmp

100.times{
  File.xpath(path, tmp)
  File.xpath('foo', tmp)
}

#p path
#p tmp

#p File.expand_path('../a', tmp)

#p File.xpath('../a', 'foo')
#p File.expand_path('../a', 'foo')
#p File.xpath('../a', 'C:/foo')
#p File.expand_path('../a', 'C:/foo')


=begin
p File.xpath("/foo").tainted?
p File.xpath("foo").tainted? # True
p File.xpath("foo".taint).tainted? # True
p File.xpath("C:/foo").tainted? # False
p File.xpath("C:/foo".taint).tainted? # True
=end

=begin
p File.xpath("~")
p File.xpath("~/foo")
p File.xpath("//foo/bar")
p File.xpath("//foo/bar//")
p File.xpath("//foo/bar//")
=end
