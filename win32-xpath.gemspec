require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'win32-xpath'
  spec.version    = '1.0.4'
  spec.author     = 'Daniel J. Berger'
  spec.license    = 'Artistic 2.0'
  spec.email      = 'djberg96@gmail.com'
  spec.homepage   = 'http://github.com/djberg96/win32-xpath'
  spec.summary    = 'Revamped File.expand_path for Windows'
  spec.test_file  = 'test/test_win32_xpath.rb'
  spec.files      = Dir['**/*'].reject{ |f| f.include?('git') }
  spec.cert_chain = Dir['certs/*']

  spec.extra_rdoc_files  = ['README', 'CHANGES', 'MANIFEST']

  spec.extensions = ['ext/extconf.rb']
  spec.add_development_dependency('rake')
  spec.add_development_dependency('test-unit', '>= 3.0.0')

  spec.description = <<-EOF
    The win32-xpath library provides a revamped File.expand_path method
    for MS Windows. It is significantly faster, and supports ~user
    expansion as well.
  EOF
end
