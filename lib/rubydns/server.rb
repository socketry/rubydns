# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2009-2017, by Samuel Williams.
# Copyright, 2011, by Genki Sugawara.
# Copyright, 2014, by Zac Sprackett.
# Copyright, 2015, by Michal Cichra.

require_relative "rule"

require "async/dns/server"

module RubyDNS
	# Provides the core of the RubyDNS domain-specific language (DSL). It contains a list of rules which are used to match against incoming DNS questions. These rules are used to generate responses which are either DNS resource records or failures.
	class Server < Async::DNS::Server
		# Instantiate a server with a block
		#
		#	server = Server.new do
		#		match(/server.mydomain.com/, IN::A) do |transaction|
		#			transaction.respond!("1.2.3.4")
		#		end
		#	end
		#
		def initialize(...)
			super
			
			@rules = []
			@otherwise = nil
		end
		
		# This function connects a pattern with a block. A pattern is either a String or a Regex instance. Optionally, a second argument can be provided which is either a String, Symbol or Array of resource record types which the rule matches against.
		# 
		#	match("www.google.com")
		#	match("gmail.com", IN::MX)
		#	match(/g?mail.(com|org|net)/, [IN::MX, IN::A])
		#
		def match(*pattern, &block)
			@rules << Rule.new(pattern, block)
		end
		
		# Specify a default block to execute if all other rules fail to match. This block is typially used to pass the request on to another server (i.e. recursive request).
		#
		#	otherwise do |transaction|
		#		transaction.passthrough!($R)
		#	end
		#
		def otherwise(&block)
			@otherwise = block
		end
		
		# If you match a rule, but decide within the rule that it isn't the correct one to use, you can call `next!` to evaluate the next rule - in other words, to continue falling down through the list of rules.
		def next!
			throw :next
		end
		
		# Give a name and a record type, try to match a rule and use it for processing the given arguments.
		def process(name, resource_class, transaction)
			Console.debug(self) {"<#{transaction.query.id}> Searching for #{name} #{resource_class.name}"}
			
			@rules.each do |rule|
				Console.debug(self) {"<#{transaction.query.id}> Checking rule #{rule}..."}
				
				catch (:next) do
					# If the rule returns true, we assume that it was successful and no further rules need to be evaluated.
					return if rule.call(self, name, resource_class, transaction)
				end
			end
			
			if @otherwise
				@otherwise.call(transaction)
			else
				@logger.warn "<#{transaction.query.id}> Failed to handle #{name} #{resource_class.name}!"
			end
		end
	end
end
