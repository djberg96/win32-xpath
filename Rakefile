require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rbconfig'
include RbConfig

CLEAN.include(
  '**/*.gem',               # Gem files
  '**/*.rbc',               # Rubinius
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

desc "Build the xpath library"
task :build => [:clean] do
  require 'devkit' if CONFIG['host_os'] =~ /mingw|cygwin/i
  Dir.chdir('ext') do
    ruby "extconf.rb"
    sh make
  end
end

Rake::TestTask.new do |t|
  task :test => [:build]
  t.test_files = FileList['test/*']
  t.libs << 'ext'
end

desc "Run benchmarks"
task :bench => [:build] do
  ruby "-Iext bench/bench_xpath.rb"
end

task :default => :test
