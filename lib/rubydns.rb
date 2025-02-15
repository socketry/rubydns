# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2009-2017, by Samuel Williams.
# Copyright, 2014, by Peter M. Goldstein.

require "async/dns"

require_relative "rubydns/version"
require_relative "rubydns/server"

module RubyDNS
	# Backwards compatibility:
	Resolver = Async::DNS::Resolver
	
	# Run a server with the given rules.
	def self.run(*arguments, server_class: Server, **options, &block)
		server = server_class.new(*arguments, **options)
		
		if block_given?
			server.instance_eval(&block)
		end
		
		return server.run
	end
	
	# @deprecated Use {RubyDNS.run} instead.
	def self.run_server(...)
		self.run(...)
	end
end
