require 'win32/xpath'
require 'tmpdir'

#p File.expand_path("~djberge", "foo")
#p File.expand_path("~/foo")
#p File.expand_path("", "~djberge")
#p File.expand_path("~djberge")
#p File.expand_path("~djberge/foo/bar")
#p File.expand_path("~bogus")

ENV['HOME'] = nil
ENV['USERPROFILE'] = nil
ENV['HOMEDRIVE'] = "D:/"
#ENV['USERPROFILE'] = "C:/bogus"
p File.expand_path("~")

#p File.expand_path("foo", "~")
#p File.expand_path("foo", "~")
#p File.expand_path("", "~")
#p File.expand_path("", "~")
#p File.expand_path("foo", "~/bar")
#p File.expand_path("foo", "~/bar")
#p File.expand_path("")
#p File.expand_path("C:/foo/bar")
#p File.expand_path("C:/foo/bar///")
#p File.expand_path('foo', Dir.tmpdir)
#p File.expand_path("C:/foo/bar", "D:/foo")
#p File.expand_path("foo")
#p File.expand_path("foo", "bar")

#ENV['HOME'] = nil
#ENV['USERPROFILE'] = nil
#p File.expand_path("~")

#path = "../a"
#tmp = Dir.tmpdir

#p path
#p tmp

#100.times{
#  File.expand_path(path, tmp)
#  File.expand_path('foo', tmp)
#}

#p path
#p tmp

#p File.expand_path('../a', tmp)

#p File.expand_path('../a', 'foo')
#p File.expand_path('../a', 'foo')
#p File.expand_path('../a', 'C:/foo')
#p File.expand_path('../a', 'C:/foo')


=begin
p File.expand_path("/foo").tainted?
p File.expand_path("foo").tainted? # True
p File.expand_path("foo".taint).tainted? # True
p File.expand_path("C:/foo").tainted? # False
p File.expand_path("C:/foo".taint).tainted? # True
=end

=begin
p File.expand_path("~")
p File.expand_path("~/foo")
p File.expand_path("//foo/bar")
p File.expand_path("//foo/bar//")
p File.expand_path("//foo/bar//")
=end
