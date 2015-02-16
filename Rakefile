require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.test_files = FileList['test/*']
end

desc "Run benchmarks"
task :bench do
  ruby "-Ilib bench/bench_xpath.rb"
end

task :default => :test
