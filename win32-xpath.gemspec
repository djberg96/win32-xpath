require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'win32-xpath'
  spec.version    = '1.1.2'
  spec.author     = 'Daniel J. Berger'
  spec.license    = 'Apache-2.0'
  spec.email      = 'djberg96@gmail.com'
  spec.homepage   = 'http://github.com/djberg96/win32-xpath'
  spec.summary    = 'Revamped File.expand_path for Windows'
  spec.test_file  = 'test/test_win32_xpath.rb'
  spec.files      = Dir['**/*'].reject{ |f| f.include?('git') }
  spec.cert_chain = Dir['certs/*']

  spec.extensions = ['ext/extconf.rb']
  spec.add_development_dependency('rake')
  spec.add_development_dependency('test-unit', '~> 3.4')

  spec.metadata = {
    'homepage_uri'      => 'https://github.com/djberg96/win32-xpath',
    'bug_tracker_uri'   => 'https://github.com/djberg96/win32-xpath/issues',
    'changelog_uri'     => 'https://github.com/djberg96/win32-xpath/blob/main/CHANGES.md',
    'documentation_uri' => 'https://github.com/djberg96/win32-xpath/wiki',
    'source_code_uri'   => 'https://github.com/djberg96/win32-xpath',
    'wiki_uri'          => 'https://github.com/djberg96/win32-xpath/wiki'
  }

  spec.description = <<-EOF
    The win32-xpath library provides a revamped File.expand_path method
    for MS Windows. It is significantly faster, and supports ~user
    expansion as well.
  EOF
end
