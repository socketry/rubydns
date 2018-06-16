
require_relative 'lib/rubydns/version'

Gem::Specification.new do |spec|
	spec.name          = "rubydns"
	spec.version       = RubyDNS::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	spec.description   = <<-EOF
		RubyDNS provides a rule-based DSL for implementing DNS servers, built on top of `Async::DNS`.
	EOF
	spec.summary       = "An easy to use DNS server and resolver for Ruby."
	spec.homepage      = "https://github.com/socketry/rubydns"
	spec.license       = "MIT"

	spec.files         = `git ls-files`.split($/)
	spec.executables   = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
	spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ["lib"]
	spec.has_rdoc = "yard"
	
	spec.add_dependency("async-dns", "~> 1.0")
	spec.add_development_dependency("async-rspec", "~> 1.0")
	
	spec.add_development_dependency "bundler", "~> 1.3"
	spec.add_development_dependency "rspec", "~> 3.4"
	spec.add_development_dependency "rake"
end
