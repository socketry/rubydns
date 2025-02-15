# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2009-2017, by Samuel Williams.
# Copyright, 2011, by Genki Sugawara.
# Copyright, 2014, by Zac Sprackett.
# Copyright, 2015, by Michal Cichra.

require "async/dns/server"

module RubyDNS
	# Represents a single rule in the server.
	class Rule
		def initialize(pattern, callback)
			@pattern = pattern
			@callback = callback
		end
		
		# Returns true if the name and resource_class are sufficient:
		def match(name, resource_class)
			# If the pattern doesn't specify any resource classes, we implicitly pass this test:
			return true if @pattern.size < 2
			
			# Otherwise, we try to match against some specific resource classes:
			if Class === @pattern[1]
				@pattern[1] == resource_class
			else
				@pattern[1].include?(resource_class) rescue false
			end
		end
		
		# Invoke the rule, if it matches the incoming request, it is evaluated and returns `true`, otherwise returns `false`.
		def call(server, name, resource_class, transaction)
			unless match(name, resource_class)
				server.logger.debug "<#{transaction.query.id}> Resource class #{resource_class} failed to match #{@pattern[1].inspect}!"
				
				return false
			end
			
			# Does this rule match against the supplied name?
			case @pattern[0]
			when Regexp
				match_data = @pattern[0].match(name)
				
				if match_data
					server.logger.debug "<#{transaction.query.id}> Regexp pattern matched with #{match_data.inspect}."
					
					@callback[transaction, match_data]
					
					return true
				end
			when String
				if @pattern[0] == name
					server.logger.debug "<#{transaction.query.id}> String pattern matched."
					
					@callback[transaction]
					
					return true
				end
			else
				if (@pattern[0].call(name, resource_class) rescue false)
					server.logger.debug "<#{transaction.query.id}> Callable pattern matched."
					
					@callback[transaction]
					
					return true
				end
			end
			
			server.logger.debug "<#{transaction.query.id}> No pattern matched."
			
			# We failed to match the pattern.
			return false
		end
		
		def to_s
			@pattern.inspect
		end
	end
end
