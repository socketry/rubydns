# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rubydns/version'

Gem::Specification.new do |spec|
	spec.name          = "rubydns"
	spec.version       = RubyDNS::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	spec.description   = <<-EOF
		RubyDNS is a high-performance DNS server which can be easily integrated into
		other projects or used as a stand-alone daemon. By default it uses
		rule-based pattern matching. Results can be hard-coded, computed, fetched from
		a remote DNS server or fetched from a local cache, depending on requirements.

		In addition, RubyDNS includes a high-performance asynchronous DNS resolver
		built on top of Celluloid. This module can be used by itself in client
		applications without using the full RubyDNS server stack.
	EOF
	spec.summary       = "An easy to use DNS server and resolver for Ruby."
	spec.homepage      = "http://www.codeotaku.com/projects/rubydns"
	spec.license       = "MIT"

	spec.files         = `git ls-files`.split($/)
	spec.executables   = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
	spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ["lib"]
	spec.has_rdoc = "yard"
	
	spec.required_ruby_version = '>= 1.9.3'

	spec.add_dependency("celluloid", "= 0.16.0")
	spec.add_dependency("celluloid-io", "= 0.16.2")
	spec.add_dependency("timers", "~> 4.0.1")
	
	spec.add_development_dependency "bundler", "~> 1.3"
	spec.add_development_dependency "process-daemon", "~> 0.5.5"
	spec.add_development_dependency "rspec", "~> 3.2.0"
	spec.add_development_dependency "rake"
end
