require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rbconfig'
include RbConfig

CLEAN.include(
  '**/*.gem',               # Gem files
  '**/*.rbc',               # Rubinius
  '**/*.lock',              # Bundler
  '**/*.o',                 # C object file
  '**/*.log',               # Ruby extension build log
  '**/Makefile',            # C Makefile
  '**/*.def',               # Definition files
  '**/*.exp',
  '**/*.lib',
  '**/*.pdb',
  '**/*.obj',
  '**/*.stackdump',         # Junk that can happen on Windows
  "**/*.#{CONFIG['DLEXT']}" # C shared object
)

make = CONFIG['host_os'] =~ /mingw|cygwin/i ? 'make' : 'nmake'

desc "Build the win32-xpath library"
task :build => [:clean] do
  require 'devkit' if CONFIG['host_os'] =~ /mingw|cygwin/i
  Dir.chdir('ext') do
    ruby "extconf.rb"
    sh make
    cp 'xpath.so', 'win32' # For testing
  end
end

namespace :gem do
  desc "Build the win32-xpath gem"
  task :create => [:clean] do
    require 'rubygems/package'
    spec = Gem::Specification.load('win32-xpath.gemspec')
    spec.signing_key = File.join(Dir.home, '.ssh', 'gem-private_key.pem')
    Gem::Package.build(spec)
  end

  task "Install the win32-xpath gem"
  task :install => [:create] do
    file = Dir["*.gem"].first
    sh "gem install -l #{file}"
  end
end

Rake::TestTask.new do |t|
  task :test => [:build]
  t.test_files = FileList['test/*']
  t.libs << 'ext'
end

desc "Run benchmarks"
task :bench => [:build] do
  ruby "-Iext bench/bench_win32_xpath.rb"
end

task :default => :test
