
Dir.chdir("../") do
	require './lib/rubydns/version'

	Gem::Specification.new do |s|
		s.name = "rubydns"
		s.version = RubyDNS::VERSION::STRING
		s.authors = ["Samuel Williams"]
		s.email = "samuel@oriontransfer.org"
		s.homepage = "http://www.codeotaku.com/projects/rubydns"
		s.platform = Gem::Platform::RUBY
		s.summary = "An easy to use DNS server and resolver for Ruby."
		s.files = FileList["{bin,lib,test}/**/*"] + ["rakefile.rb", "Gemfile", "README.md"]

		s.executables << "rd-resolve-test"
		s.executables << "rd-dns-check"

		s.add_dependency("rexec", "~> 1.5.0")
		s.add_dependency("eventmachine", "~> 1.0.0")
		
		s.has_rdoc = "yard"
	end
end

