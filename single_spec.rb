require 'rspec'
require 'tmpdir'
require 'win32/xpath'
require 'etc'

# Test individual spec cases to isolate the segfault
describe 'Single spec test' do
  let!(:login) { Etc.getlogin }
  let!(:env){ ENV.to_h }

  before do
    @pwd = Dir.pwd
    @tmp = 'C:/Temp'
    @root =  'C:/'
    @drive = Dir.pwd[0,2]
    @home = env['HOME'].tr('\\', '/')
    @unc = "//foo/bar"
    ENV['HOME'] = env['USERPROFILE'] || Dir.home
  end

  after do
    ENV.replace(env)
  end

  it "converts an empty pathname into absolute current pathname" do
    result = File.expand_path('')
    expect(result).to eq(@pwd)
    puts "Empty path test passed: #{result}"
  end
  
  it "converts relative path into absolute pathname using current directory" do
    result = File.expand_path('foo')
    expect(result).to eq(File.join(@pwd, 'foo'))
    puts "Relative path test passed: #{result}"
  end
  
  it "converts relative path and directory into the expected absolute pathname" do
    result = File.expand_path('foo', 'bar')
    expect(result).to eq(File.join(@pwd, 'bar', 'foo'))
    puts "Relative with dir test passed: #{result}"
  end
end
