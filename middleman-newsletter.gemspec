# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "middleman-newsletter"
  s.version     = "0.0.8"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Alex Scarborough"]
  # s.email       = ["email@example.com"]
  # s.homepage    = "http://example.com"
  s.summary     = %q{Convert middleman blogs into a newsletter}
  # s.description = %q{A longer description of your extension}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # The version of middleman-core your extension depends on
  s.add_runtime_dependency("middleman-core", [">= 4.4.0"])
  s.add_runtime_dependency("middleman-blog", [">= 4.0.3"])
  s.add_runtime_dependency("premailer", ["~> 1.22"])
  s.add_runtime_dependency("sendgrid-ruby", ["~> 6.7"])

  # Additional dependencies
  # s.add_runtime_dependency("gem-name", "gem-version")
end
