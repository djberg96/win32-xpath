require 'test-unit'
require 'tmpdir'
require 'xpath'
require 'etc'

class Test_XPath < Test::Unit::TestCase
  def self.startup
    ENV['HOME'] ||= ENV['USERPROFILE']
    @@login = Etc.getlogin
  end

  def setup
    @pwd = Dir.pwd
    @tmp = Dir.tmpdir
    @root =  'C:/'
    @drive = ENV['HOMEDRIVE']
    @home = ENV['HOME'].tr('\\', '/')
    @unc = "//foo/bar"
  end

  test "converts an empty pathname into absolute current pathname" do
    assert_equal(@pwd, File.xpath(''))
  end

  test "converts '.' into absolute pathname using current directory" do
    assert_equal(@pwd, File.xpath('.'))
  end

  test "converts 'foo' into absolute pathname using current directory" do
    assert_equal(File.join(@pwd, 'foo'), File.xpath('foo'))
  end

  test "converts 'foo' into absolute pathname ignoring nil dir" do
    assert_equal(File.join(@pwd, 'foo'), File.xpath('foo', nil))
  end

  test "converts 'foo' and 'bar' into absolute pathname" do
    assert_equal(File.join(@pwd, "bar", "foo"), File.xpath('foo', 'bar'))
  end

  test "converts a pathname into absolute pathname" do
    assert_equal(File.join(@pwd, 'a'), File.xpath('a.'))
    assert_equal(File.join(@pwd, '.a'), File.xpath('.a'))
    assert_equal(File.join(@pwd, '..a'), File.xpath('..a'))
    assert_equal(File.join(@pwd, 'a../b'), File.xpath('a../b'))
  end

  test "converts a pathname and make it valid" do
    assert_equal(File.join(@pwd, 'a'), File.xpath('a..'))
  end

  test "converts a pathname to an absolute pathname using a complete path" do
    assert_equal(@tmp, File.xpath('', @tmp))
    assert_equal(File.join(@tmp, 'a'), File.xpath('a', @tmp))
    assert_equal(File.join(@tmp, 'a'), File.xpath('../a', "#{@tmp}/xxx"))
    assert_equal(@root, File.xpath('.', @root))
  end

  test "ignores supplied dir if path contains a drive letter" do
    assert_equal(@root, File.xpath(@root, "D:/"))
  end

  test "removes trailing slashes from absolute path" do
    assert_equal(File.join(@root, 'foo'), File.xpath("#{@root}foo/"))
    assert_equal(File.join(@root, 'foo.rb'), File.xpath("#{@root}foo.rb/"))
  end

  test "removes trailing spaces from absolute path" do
    assert_equal(File.join(@root, 'foo'), File.xpath("#{@root}foo  "))
  end

  test "removes trailing dots from absolute path" do
    assert_equal(File.join(@root, 'a'), File.xpath("#{@root}a."))
  end

  test "converts a pathname with a drive letter but no slash" do
    assert_match(/\Ac:\//i, File.xpath("c:"))
  end

  test "converts a pathname with a drive letter ignoring different drive dir" do
    assert_match(/\Ac:\//i, File.xpath("c:foo", "d:/bar"))
  end

  test "converts a pathname which starts with a slash using current drive" do
    assert_match(/\A#{@drive}\/foo\z/i, File.xpath('/foo'))
  end

  test "returns tainted strings or not" do
    assert_true(File.xpath('foo').tainted?)
    assert_true(File.xpath('foo'.taint).tainted?)
    assert_true(File.xpath('/foo').tainted?)
    assert_true(File.xpath('/foo'.taint).tainted?)
    assert_true(File.xpath('C:/foo'.taint).tainted?)
    assert_false(File.xpath('C:/foo').tainted?)
    assert_false(File.xpath('//foo').tainted?)
  end

  test "converts a pathname to an absolute pathname using tilde as base" do
    assert_equal(@home, File.xpath('~'))
    assert_equal("#{@home}/foo", File.xpath('~/foo'))
  end

  test "converts a pathname to an absolute pathname using tilde for UNC path" do
    ENV['HOME'] = @unc
    assert_equal(@unc, File.xpath('~'))
  end

  test "converts a tilde to path if used for dir argument" do
    assert_equal(@home, File.xpath('', '~'))
    assert_equal("#{@home}/foo", File.xpath('', '~/foo'))
    assert_equal("#{@home}/foo", File.xpath('foo', '~'))
  end

  test "does not modify a HOME string argument" do
    str = "~/a"
    assert_equal("#{@home}/a", File.xpath(str))
    assert_equal("~/a", str)
  end

  test "raises ArgumentError when HOME is nil" do
    ENV['HOME'] = nil
    ENV['USERPROFILE'] = nil
    assert_raise(ArgumentError){ File.xpath('~') }
  end

  test "raises ArgumentError if HOME is relative" do
    ENV['HOME'] = '.'
    assert_raise(ArgumentError){ File.xpath('~') }
  end

  test "raises ArgumentError if relative user is provided" do
    ENV['HOME'] = '.'
    assert_raise(ArgumentError){ File.xpath('~anything') }
  end

  test "raises an ArgumentError if a bogus username is supplied" do
    assert_raise(ArgumentError){ File.xpath('~anything') }
  end

  test "converts a tilde plus username as expected" do
    assert_equal("C:/Users/#{@@login}", File.xpath("~#{@@login}"))
    assert_equal("C:/Users/#{@@login}/foo", File.xpath("~#{@@login}/foo"))
  end

  test "raises a TypeError if not passed a string" do
    assert_raise(TypeError){ File.xpath(1) }
    assert_raise(TypeError){ File.xpath(nil) }
    assert_raise(TypeError){ File.xpath(true) }
  end

  test "canonicalizes absolute path" do
    assert_equal("C:/dir", File.xpath("C:/./dir"))
  end

  test "does not modify its argument" do
    str = "./a/b/../c"
    assert_equal("#{@home}/a/c", File.xpath(str, @home))
    assert_equal("./a/b/../c", str)
  end

  test "accepts objects that have a to_path method" do
    klass = Class.new{ def to_path; "a/b/c"; end }
    obj = klass.new
    assert_equal("#{@pwd}/a/b/c", File.xpath(obj))
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
