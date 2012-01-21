# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "acts_as_versionable/version"

Gem::Specification.new do |s|
  s.name        = "acts_as_versionable"
  s.version     = ActsAsVersionable::VERSION
  s.authors     = ["carlos segura"]
  s.email       = ["csegura@ideseg.com"]
  s.homepage    = ""
  s.summary     = %q{Minimalist engine for versions}
  s.description = %q{Maintain versions in same table only add two fields version_number:integer and version_id:integer}

  s.rubyforge_project = "acts_as_versionable"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
