require 'test-unit'
require 'tmpdir'
require 'win32/xpath'
require 'etc'

class Test_XPath < Test::Unit::TestCase
  def self.startup
    ENV['HOME'] ||= ENV['USERPROFILE']
    @@login = Etc.getlogin
  end

  def setup
    @pwd = Dir.pwd
    @tmp = 'C:/Temp'
    @root =  'C:/'
    @drive = ENV['HOMEDRIVE']
    @home = ENV['HOME'].tr('\\', '/')
    @unc = "//foo/bar"
  end

  test "converts an empty pathname into absolute current pathname" do
    assert_equal(@pwd, File.expand_path(''))
  end

  test "converts '.' into absolute pathname using current directory" do
    assert_equal(@pwd, File.expand_path('.'))
  end

  test "converts 'foo' into absolute pathname using current directory" do
    assert_equal(File.join(@pwd, 'foo'), File.expand_path('foo'))
  end

  test "converts 'foo' into absolute pathname ignoring nil dir" do
    assert_equal(File.join(@pwd, 'foo'), File.expand_path('foo', nil))
  end

  test "converts 'foo' and 'bar' into absolute pathname" do
    assert_equal(File.join(@pwd, "bar", "foo"), File.expand_path('foo', 'bar'))
  end

  test "converts a pathname into absolute pathname" do
    assert_equal(File.join(@pwd, 'a'), File.expand_path('a.'))
    assert_equal(File.join(@pwd, '.a'), File.expand_path('.a'))
    assert_equal(File.join(@pwd, '..a'), File.expand_path('..a'))
    assert_equal(File.join(@pwd, 'a../b'), File.expand_path('a../b'))
  end

  test "converts a pathname and make it valid" do
    assert_equal(File.join(@pwd, 'a'), File.expand_path('a..'))
  end

  test "converts a pathname to an absolute pathname using a complete path" do
    assert_equal(@tmp, File.expand_path('', @tmp))
    assert_equal(File.join(@tmp, 'a'), File.expand_path('a', @tmp))
    assert_equal(File.join(@tmp, 'a'), File.expand_path('../a', "#{@tmp}/xxx"))
    assert_equal(@root, File.expand_path('.', @root))
  end

  test "ignores supplied dir if path contains a drive letter" do
    assert_equal(@root, File.expand_path(@root, "D:/"))
  end

  test "removes trailing slashes from absolute path" do
    assert_equal(File.join(@root, 'foo'), File.expand_path("#{@root}foo/"))
    assert_equal(File.join(@root, 'foo.rb'), File.expand_path("#{@root}foo.rb/"))
  end

  test "removes trailing slashes from relative path" do
    assert_equal(File.join(@pwd, 'foo'), File.expand_path("foo/"))
    assert_equal(File.join(@pwd, 'foo'), File.expand_path("foo//"))
    assert_equal(File.join(@pwd, 'foo'), File.expand_path("foo\\\\\\"))
  end

  test "removes trailing spaces from absolute path" do
    assert_equal(File.join(@root, 'foo'), File.expand_path("#{@root}foo  "))
  end

  test "removes trailing dots from absolute path" do
    assert_equal(File.join(@root, 'a'), File.expand_path("#{@root}a."))
  end

  test "converts a pathname with a drive letter but no slash" do
    assert_match(/\Ac:\//i, File.expand_path("c:"))
  end

  test "converts a pathname with a drive letter ignoring different drive dir" do
    assert_match(/\Ac:\//i, File.expand_path("c:foo", "d:/bar"))
  end

  test "converts a pathname which starts with a slash using current drive" do
    assert_match(/\A#{@drive}\/foo\z/i, File.expand_path('/foo'))
  end

  test "returns tainted strings or not" do
    assert_true(File.expand_path('foo').tainted?)
    assert_true(File.expand_path('foo'.taint).tainted?)
    assert_true(File.expand_path('/foo').tainted?)
    assert_true(File.expand_path('/foo'.taint).tainted?)
    assert_true(File.expand_path('C:/foo'.taint).tainted?)
    assert_false(File.expand_path('C:/foo').tainted?)
    assert_false(File.expand_path('//foo').tainted?)
  end

  test "converts a pathname to an absolute pathname using tilde as base" do
    assert_equal(@home, File.expand_path('~'))
    assert_equal("#{@home}/foo", File.expand_path('~/foo'))
    assert_equal("#{@home}/.foo", File.expand_path('~/.foo'))
  end

  test "converts a pathname to an absolute pathname using tilde for UNC path" do
    ENV['HOME'] = @unc
    assert_equal(@unc, File.expand_path('~'))
  end

  test "converts a tilde to path if used for dir argument" do
    assert_equal(@home, File.expand_path('', '~'))
    assert_equal("#{@home}/foo", File.expand_path('', '~/foo'))
    assert_equal("#{@home}/foo", File.expand_path('foo', '~'))
  end

  test "doesn't attempt to expand a tilde unless it's the first character" do
    assert_equal("C:/Progra~1", File.expand_path("C:/Progra~1"))
    assert_equal("C:/Progra~1", File.expand_path("C:/Progra~1", "C:/Progra~1"))
  end

  test "does not modify a HOME string argument" do
    str = "~/a"
    assert_equal("#{@home}/a", File.expand_path(str))
    assert_equal("~/a", str)
  end

  test "defaults to HOMEDRIVE + HOMEPATH if HOME or USERPROFILE are nil" do
    ENV['HOME'] = nil
    ENV['USERPROFILE'] = nil
    ENV['HOMEDRIVE'] = "C:"
    ENV['HOMEPATH'] = "\\Users\\foo"
    assert_equal("C:/Users/foo/bar", File.expand_path("~/bar"))
  end

  test "raises ArgumentError when HOME is nil" do
    ENV['HOME'] = nil
    ENV['USERPROFILE'] = nil
    ENV['HOMEDRIVE'] = nil
    assert_raise(ArgumentError){ File.expand_path('~') }
  end

  test "raises ArgumentError if HOME is relative" do
    ENV['HOME'] = '.'
    assert_raise(ArgumentError){ File.expand_path('~') }
  end

  test "raises ArgumentError if relative user is provided" do
    ENV['HOME'] = '.'
    assert_raise(ArgumentError){ File.expand_path('~anything') }
  end

  test "raises an ArgumentError if a bogus username is supplied" do
    assert_raise(ArgumentError){ File.expand_path('~anything') }
  end

  test "converts a tilde plus username as expected" do
    assert_equal("C:/Users/#{@@login}", File.expand_path("~#{@@login}"))
    assert_equal("C:/Users/#{@@login}/foo", File.expand_path("~#{@@login}/foo"))
  end

  test "raises a TypeError if not passed a string" do
    assert_raise(TypeError){ File.expand_path(1) }
    assert_raise(TypeError){ File.expand_path(nil) }
    assert_raise(TypeError){ File.expand_path(true) }
  end

  test "canonicalizes absolute path" do
    assert_equal("C:/dir", File.expand_path("C:/./dir"))
  end

  test "does not modify its argument" do
    str = "./a/b/../c"
    assert_equal("#{@home}/a/c", File.expand_path(str, @home))
    assert_equal("./a/b/../c", str)
  end

  test "accepts objects that have a to_path method" do
    klass = Class.new{ def to_path; "a/b/c"; end }
    obj = klass.new
    assert_equal("#{@pwd}/a/b/c", File.expand_path(obj))
  end

  test "works with unicode characters" do
    assert_equal("#{@pwd}/Ελλάσ", File.expand_path("Ελλάσ"))
  end

  # The +1 below is for the slash trailing @pwd that's appended.
  test "handles paths longer than 260 (MAX_PATH) characters" do
    assert_nothing_raised{ File.expand_path("a" * 261) }
    assert_nothing_raised{ File.expand_path("a" * 1024) }
    assert_equal(@pwd.size + 1024 + 1, File.expand_path("a" * 1024).size)
  end

  test "handles very long paths with tilde" do
    path = "a * 1024"
    assert_nothing_raised{ File.expand_path("~/#{path}") }
  end

  def teardown
    @pwd = nil
    @unc = nil
    @dir = nil
    @root = nil
    @drive = nil

    ENV['HOME'] = @home
  end

  def self.shutdown
    @@login = nil
  end
end
