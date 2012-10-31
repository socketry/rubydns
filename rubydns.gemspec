# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rubydns/version'

Gem::Specification.new do |gem|
	gem.name          = "rubydns"
	gem.version       = RubyDNS::VERSION
	gem.authors       = ["Samuel Williams"]
	gem.email         = ["samuel.williams@oriontransfer.co.nz"]
	gem.description   = <<-EOF
	RubyDNS is a high-performance DNS server which can be easily integrated into
	other projects or used as a stand-alone daemon (via RExec). By default it uses
	rule-based pattern matching. Results can be hard-coded, computed, fetched from
	a remote DNS server or fetched from a local cache, depending on requirements.

	In addition, RubyDNS includes a high-performance asynchronous DNS resolver
	built on top of EventMachine. This module can be used by itself in client
	applications without using the full RubyDNS server stack.
	EOF
	gem.summary       = "An easy to use DNS server and resolver for Ruby."
	gem.homepage      = "https://github.com/ioquatix/rubydns"

	gem.files         = `git ls-files`.split($/)
	gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
	gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
	gem.require_paths = ["lib"]

	gem.add_dependency("rexec", "~> 1.5.1")
	gem.add_dependency("eventmachine", "~> 1.0.0")

	gem.has_rdoc = "yard"
end
