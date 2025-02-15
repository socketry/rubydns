# frozen_string_literal: true

require_relative "lib/rubydns/version"

Gem::Specification.new do |spec|
	spec.name = "rubydns"
	spec.version = RubyDNS::VERSION
	
	spec.summary = "An easy to use DNS server and resolver for Ruby."
	spec.authors = ["Samuel Williams", "Peter M. Goldstein", "Erran Carey", "Keith Larrimore", "Alexey Pisarenko", "Chris Cunningham", "Genki Sugawara", "Jean-Christophe Cyr", "John Bachir", "Mark Van de Vyver", "Michal Cichra", "Olle Jonsson", "Rob Fors", "Satoshi Takada", "The Gitter Badger", "Timothy Redaelli", "Zac Sprackett", "justfalter", "kaleforsale"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/rubydns"
	
	spec.metadata = {
		"source_code_uri" => "https://github.com/socketry/rubydns.git",
	}
	
	spec.files = Dir.glob(["{bin,examples,lib,spec}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.executables = ["rubydns-check"]
	
	spec.required_ruby_version = ">= 3.1"
	
	spec.add_dependency "async-dns", "~> 1.0"
end
