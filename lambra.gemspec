# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "lambra/version"

Gem::Specification.new do |s|
  s.name        = "lambra"
  s.version     = Lambra::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Josep M. Bach"]
  s.email       = ["josep.m.bach@gmail.com"]
  s.homepage    = "https://github.com/txus/lambra"
  s.summary     = %q{An exploratory implementation of a functional, distributed Lisp on the Rubinius VM}
  s.description =<<-EOD
Lambra is an experiment to implement a functional, distributed Lisp on the
Rubinius VM (http://rubini.us).
  EOD

  s.files         = `git ls-files`.split("\n")
  s.test_files    = Dir["test/**/*.rb"]
  s.executables   = ["lambra"]
  s.require_paths = ["lib"]
end
