# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'egalite/version'

Gem::Specification.new do |spec|
  spec.name          = "egalite"
  spec.version       = Egalite::VERSION
  spec.authors       = ["Shunichi Arai"]
  spec.email         = ["arai@mellowtone.co.jp"]
  spec.description   = %q{Egalite - yet another web application framework. see description at https://github.com/araipiyo/egalite}
  spec.summary       = %q{Egalite - yet another web application framework.}
  spec.homepage      = "https://github.com/araipiyo/egalite"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 2.2.10"
  spec.add_development_dependency "rake"
  spec.add_dependency "rack"
end
