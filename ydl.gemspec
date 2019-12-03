# coding: utf-8

lib = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ydl/version'

Gem::Specification.new do |spec|
  spec.name          = 'ydl'
  spec.version       = Ydl::VERSION
  spec.authors       = ['Daniel E. Doherty']
  spec.email         = ['ded@ddoherty.net']

  spec.summary       = 'Object definition and instantiation using YAML files for Ruby programs'
  spec.description   = <<~DESC
    Ydl provides a way to supply a ruby app with initialized objects by allowing
    the user to supply the data about the objects in a hierarchical series of
    "data definition files" with the extension .ydl.
  DESC
  spec.homepage      = 'https://github.com/ddoherty03/ydl.git'
  spec.license       = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = 'bin'
  # spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'
  spec.add_dependency 'fat_core'
  spec.add_dependency 'psych'

  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'pry-doc'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  # spec.add_development_dependency 'law_doc'
end
