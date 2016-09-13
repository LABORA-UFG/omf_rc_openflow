# -*- encoding: utf-8 -*-
require File.expand_path('../lib/omf_rc_openflow/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Kostas Choumas"]
  gem.email         = ["kohoumas@gmail.com"]
  gem.description   = %q{OMF6 Resource Controllers related to the Openflow technology}
  gem.summary       = %q{OMF6 Resource Controllers related to the Openflow technology, including the Stanford software tools named FlowVisor and OpenvSwitch}
  gem.homepage      = "http://nitlab.inf.uth.gr"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "omf_rc_openflow"
  gem.require_paths = ["lib"]
  gem.version       = OmfRcOpenflow::VERSION
  gem.add_runtime_dependency "omf_rc", "~> 6.2.3"
end
