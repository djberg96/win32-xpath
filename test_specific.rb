require 'rspec'
require 'tmpdir'
require 'win32/xpath'
require 'etc'

RSpec.describe 'Specific failing test' do
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

  example "converts a pathname to an absolute pathname using a complete path" do
    puts "Testing: File.expand_path('../a', '#{@tmp}/xxx')"
    result = File.expand_path('../a', "#{@tmp}/xxx")
    expected = File.join(@tmp, 'a')
    puts "Result: #{result}"
    puts "Expected: #{expected}"
    expect(result).to eq(expected)
  end
end
