require 'rspec'
require 'tmpdir'
require 'win32/xpath'
require 'etc'

RSpec.describe 'win32-xpath' do  
  let(:login) { Etc.getlogin }

  #before(:context) do
  #end

  before do
    @pwd = Dir.pwd
    @tmp = 'C:/Temp'
    @root =  'C:/'
    @drive = ENV['HOMEDRIVE']
    @home = ENV['HOME'].tr('\\', '/')
    @unc = "//foo/bar"
    ENV['HOME'] = ENV['USERPROFILE'] || Dir.home
  end

  example "converts an empty pathname into absolute current pathname" do
    expect(File.expand_path('')).to eq(@pwd)
  end

  example "converts '.' into absolute pathname using current directory" do
    expect(File.expand_path('.')).to eq(@pwd)
  end

  example "converts relative path into absolute pathname using current directory" do
    expect(File.expand_path('foo')).to eq(File.join(@pwd, 'foo'))
  end

  example "converts relative path into absolute pathname ignoring nil dir" do
    expect(File.expand_path('foo', nil)).to eq(File.join(@pwd, 'foo'))
  end

  example "converts relative path and directory into the expected absolute pathname" do
    expect(File.expand_path('foo', 'bar')).to eq(File.join(@pwd, 'bar', 'foo'))
  end

  example "converts relative edge case pathnames into absolute pathnames" do
    expect(File.expand_path('a.')).to eq(File.join(@pwd, 'a'))
    expect(File.expand_path('.a')).to eq(File.join(@pwd, '.a'))
    expect(File.expand_path('..a')).to eq(File.join(@pwd, '..a'))
    expect(File.expand_path('a../b')).to eq(File.join(@pwd, 'a../b'))
  end

  example "converts a double dot pathname into the expected absolute pathname" do
    expect( File.expand_path('a..')).to eq(File.join(@pwd, 'a'))
  end

  example "converts a pathname to an absolute pathname using a complete path" do
    #expect(@tmp)).to eq(File.join(@tmp, 'a'), File.expand_path('a')
    #expect("#{@tmp}/xxx")).to eq(File.join(@tmp, 'a'), File.expand_path('../a')
    #expect(@root)).to eq(@root, File.expand_path('.')
  end

=begin
  example "ignores supplied dir if path contains a drive letter" do
    expect( "D:/")).to eq(@root, File.expand_path(@root)
  end

  example "removes trailing slashes from absolute path" do
    expect( File.expand_path("#{@root}foo/")).to eq(File.join(@root, 'foo'))
    expect( File.expand_path("#{@root}foo.rb/")).to eq(File.join(@root, 'foo.rb'))
  end

  example "removes trailing slashes from relative path" do
    expect( File.expand_path("foo/")).to eq(File.join(@pwd, 'foo'))
    expect( File.expand_path("foo//")).to eq(File.join(@pwd, 'foo'))
    expect( File.expand_path("foo\\\\\\")).to eq(File.join(@pwd, 'foo'))
  end

  example "removes trailing spaces from absolute path" do
    expect( File.expand_path("#{@root}foo  ")).to eq(File.join(@root, 'foo'))
  end

  example "removes trailing dots from absolute path" do
    expect( File.expand_path("#{@root}a.")).to eq(File.join(@root, 'a'))
  end

  example "converts a pathname with a drive letter but no slash" do
    expect( File.expand_path("c:")).to match(/\Ac:\//i)
  end

  example "converts a pathname with a drive letter ignoring different drive dir" do
    expect( "d:/bar")).to match(/\Ac:\//i, File.expand_path("c:foo")
  end

  example "converts a pathname which starts with a slash using current drive" do
    expect( File.expand_path('/foo')).to match(/\A#{@drive}\/foo\z/i)
  end

  example "returns tainted strings or not" do
    expect(File.expand_path('foo').tainted?).to be true
    expect(File.expand_path('foo'.taint).tainted?).to be true
    expect(File.expand_path('/foo').tainted?).to be true
    expect(File.expand_path('/foo'.taint).tainted?).to be true
    expect(File.expand_path('C:/foo'.taint).tainted?).to be true
    expect(File.expand_path('C:/foo').tainted?).to be false
    expect(File.expand_path('//foo').tainted?).to be false
  end

  example "converts a pathname to an absolute pathname using tilde as base" do
    expect( File.expand_path('~')).to eq(@home)
    expect( File.expand_path('~/foo')).to eq("#{@home}/foo")
    expect( File.expand_path('~/.foo')).to eq("#{@home}/.foo")
  end

  example "converts a pathname to an absolute pathname using tilde for UNC path" do
    ENV['HOME'] = @unc
    expect( File.expand_path('~')).to eq(@unc)
  end

  example "converts a tilde to path if used for dir argument" do
    expect( '~')).to eq(@home, File.expand_path('')
    expect( '~/foo')).to eq("#{@home}/foo", File.expand_path('')
    expect( '~')).to eq("#{@home}/foo", File.expand_path('foo')
  end

  example "doesn't attempt to expand a tilde unless it's the first character" do
    expect( File.expand_path("C:/Progra~1")).to eq("C:/Progra~1")
    expect( "C:/Progra~1")).to eq("C:/Progra~1", File.expand_path("C:/Progra~1")
  end

  example "does not modify a HOME string argument" do
    str = "~/a"
    expect( File.expand_path(str)).to eq("#{@home}/a")
    expect( str).to eq("~/a")
  end

  example "defaults to HOMEDRIVE + HOMEPATH if HOME or USERPROFILE are nil" do
    ENV['HOME'] = nil
    ENV['USERPROFILE'] = nil
    ENV['HOMEDRIVE'] = "C:"
    ENV['HOMEPATH'] = "\\Users\\foo"
    expect( File.expand_path("~/bar")).to eq("C:/Users/foo/bar")
  end

  example "raises ArgumentError when HOME is nil" do
    ENV['HOME'] = nil
    ENV['USERPROFILE'] = nil
    ENV['HOMEDRIVE'] = nil
    expect{ File.expand_path('~') }.to raise_error(ArgumentError)
  end

  example "raises ArgumentError if HOME is relative" do
    ENV['HOME'] = '.'
    expect{ File.expand_path('~') }.to raise_error(ArgumentError)
  end
=end 

  #example "raises ArgumentError if relative home dir with tilde is provided" do
  #  ENV['HOME'] = 'whatever'
  #  expect(File.expand_path("~#{login}")).to eq('foo')
  #end

  example "raises an ArgumentError if a bogus username is supplied" do
    expect{ File.expand_path('~anything') }.to raise_error(ArgumentError)
  end

  example "converts a tilde plus username as expected" do
    expect(File.expand_path("~#{login}")).to eq("C:/Users/#{login}")
    expect(File.expand_path("~#{login}/foo")).to eq("C:/Users/#{login}/foo")
  end

  example "raises a TypeError if not passed a string" do
    expect{ File.expand_path(1) }.to raise_error(TypeError)
    expect{ File.expand_path(nil) }.to raise_error(TypeError)
    expect{ File.expand_path(true) }.to raise_error(TypeError)
  end

  example "canonicalizes absolute path" do
    expect(File.expand_path("C:/./dir")).to eq("C:/dir")
  end

  example "does not modify its argument" do
    str = "./a/b/../c"
    expect(File.expand_path(str, @home)).to eq("#{@home}/a/c")
    expect(str).to eq("./a/b/../c")
  end

  example "accepts objects that have a to_path method" do
    klass = Class.new{ def to_path; "a/b/c"; end }
    obj = klass.new
    expect(File.expand_path(obj)).to eq("#{@pwd}/a/b/c")
  end

  example "works with unicode characters" do
    expect( File.expand_path("Ελλάσ")).to eq("#{@pwd}/Ελλάσ")
  end

  # The +1 below is for the slash trailing @pwd that's appended.
  example "handles paths longer than 260 (MAX_PATH) characters" do
    expect{ File.expand_path("a" * 261) }.not_to raise_error
    expect{ File.expand_path("a" * 1024) }.not_to raise_error
    expect(File.expand_path("a" * 1024).size).to eq(@pwd.size + 1024 + 1)
  end

  example "handles very long paths with tilde" do
    path = "a * 1024"
    expect{ File.expand_path("~/#{path}") }.not_to raise_error
  end
end
