require 'test-unit'
require 'tmpdir'
require 'file'

class Test_XPath < Test::Unit::TestCase
  def self.startup
    ENV['HOME'] ||= ENV['USERPROFILE']
  end

  def setup
    @pwd = Dir.pwd
    @tmp = Dir.tmpdir
    @root =  'C:/'
    @drive = ENV['HOMEDRIVE']
    @home = ENV['HOME'].tr('\\', '/')
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

  #test "converts 'foo' and 'bar' into absolute pathname" do
  #  assert_equal(File.join(@pwd, "bar", "foo"), File.xpath('foo', 'bar'))
  #end

  test "converts a pathname into absolute pathname" do
    assert_equal(File.join(@pwd, 'a'), File.xpath('a.'))
    assert_equal(File.join(@pwd, '.a'), File.xpath('.a'))
    assert_equal(File.join(@pwd, '..a'), File.xpath('..a'))
    assert_equal(File.join(@pwd, 'a../b'), File.xpath('a../b'))
  end

  test "converts a pathname and make it valid" do
    assert_equal(File.join(@pwd, 'a'), File.xpath('a..'))
  end

  #test "converts a pathname to an absolute pathname using a complete path" do
  #  assert_equal(@tmp, File.xpath('', @tmp))
  #  assert_equal(File.join(@tmp, 'a'), File.xpath('a', @tmp))
  #  assert_equal(File.join(@tmp, 'a'), File.xpath('../a', @tmp))
  #  assert_equal(File.join(@tmp, 'a'), File.xpath('../a', "#{@tmp}/xxx"))
  #  assert_equal(@root, File.xpath('.', @root))
  #end

  #test "ignores supplied dir if path contains a drive letter" do
  #  assert_equal(@root, File.xpath(@root, "D:/"))
  #end

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

  #test "removes trailing invalid ':$DATA' from absolute path" do
  #  assert_equal(File.join(@root, 'aaa'), File.xpath("#{@root}/aaa::$DATA"))
  #  assert_equal(File.join(@root, 'aa:a'), File.xpath("#{@root}/aa:a:$DATA"))
  #  assert_equal(File.join(@root, 'aaa:$DATA'), File.xpath("#{@root}/aaa:$DATA"))
  #end

  test "converts a pathname with a drive letter but no slash" do
    assert_match(/\Ac:\//i, File.xpath("c:"))
  end

  #test "converts a pathname with a drive letter ignoring different drive dir" do
  #  assert_match(/\Ac:\//i, File.xpath("c:foo", "d:/bar"))
  #end

  #test "converts a pathname with a drive letter using same drive dir" do
  #  assert_match(/\Ac:\/bar\/foo\z/i, File.xpath("c:foo", "c:/bar"))
  #end

  test "converts a pathname which starts with a slash using current drive" do
    assert_match(/\A#{@drive}\/foo\z/i, File.xpath('/foo'))
  end

  # These taint rules are STOOOPID
  test "returns tainted strings or not" do
    assert_true(File.xpath('foo').tainted?)
    assert_true(File.xpath('foo'.taint).tainted?)
    assert_true(File.xpath('/foo').tainted?)
    assert_true(File.xpath('/foo'.taint).tainted?)
    assert_true(File.xpath('C:/foo'.taint).tainted?)

    #assert_false(File.xpath('C:/foo').tainted?)
    #assert_false(File.xpath('//foo').tainted?)
  end

  test "converts a pathname to an absolute pathname using '~' as base" do
    assert_equal(@home, File.xpath('~'))
  end

  def teardown
    @pwd = nil
    @dir = nil
    @root = nil
    @drive = nil

    ENV['HOME'] = @home
  end
end
