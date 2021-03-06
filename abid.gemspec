# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'abid/version'

Gem::Specification.new do |spec|
  spec.name          = 'abid'
  spec.version       = Abid::VERSION
  spec.authors       = ['Hikaru Ojima']
  spec.email         = ['amijo4rihaku@gmail.com']

  spec.summary       = 'Abid is a simple Workflow Engine based on Rake.'
  spec.description   = 'Abid is a simple Workflow Engine based on Rake.'
  spec.homepage      = 'https://github.com/ojima-h/abid'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|sample)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'yard'

  spec.add_dependency 'rake'
  spec.add_dependency 'concurrent-ruby-ext'
  spec.add_dependency 'sequel'
  spec.add_dependency 'sqlite3'
  spec.add_dependency 'thor'
end
