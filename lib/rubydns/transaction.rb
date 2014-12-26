# Copyright, 2009, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

module RubyDNS
	
	# This class provides all details of a single DNS question and response. This is used by the DSL to provide DNS related functionality.
	# 
	# The main functions to complete the transaction are: {#append!} (evaluate a new query and append the results), {#passthrough!} (pass the query to an upstream server), {#respond!} (compute a specific response) and {#fail!} (fail with an error code).
	class Transaction
		# The default time used for responses (24 hours).
		DEFAULT_TTL = 86400
		
		def initialize(server, query, question, resource_class, response, options = {})
			@server = server
			@query = query
			@question = question
			@resource_class = resource_class
			@response = response

			@options = options
		end

		# The resource_class that was requested. This is typically used to generate a response.
		attr :resource_class
		
		# The incoming query which is a set of questions.
		attr :query
		
		# The question that this transaction represents.
		attr :question
		
		# The current full response to the incoming query.
		attr :response
		
		# Any options or configuration associated with the given transaction.
		attr :options
		
		def [] key
			@options[key]
		end
		
		# The name of the question, which is typically the requested hostname.
		def name
			@question.to_s
		end
		
		# Shows the question name and resource class. Suitable for debugging purposes.
		def to_s
			"#{name} #{@resource_class.name}"
		end
		
		# Run a new query through the rules with the given name and resource type. The results of this query are appended to the current transaction's `response`.
		def append!(name, resource_class = nil, options = {})
			Transaction.new(@server, @query, name, resource_class || @resource_class, @response, options).process
		end
		
		# Use the given resolver to respond to the question. Uses `passthrough` to do the lookup and merges the result.
		#
		# If a block is supplied, this function yields with the `response` message if successful. This could be used, for example, to update a cache or modify the reply.
		#
		# If recursion is not requested, the result is `fail!(:Refused)`. This check is ignored if an explicit `options[:name]` or `options[:force]` is given.
		#
		# If the resolver can't reach upstream servers, `fail!(:ServFail)` is invoked.
		def passthrough!(resolver, options = {}, &block)
			if @query.rd || options[:force] || options[:name]
				response = passthrough(resolver, options)
				
				if response
					yield response if block_given?
					
					# Recursion is available and is being used:
					# See issue #26 for more details.
					@response.ra = 1
					@response.merge!(response)
				else
					fail!(:ServFail)
				end
			else
				fail!(:Refused)
			end
		end
		
		# Use the given resolver to respond to the question.
		# 
		# A block must be supplied, and provided a valid response is received from the upstream server, this function yields with the reply and reply_name.
		#
		# If `options[:name]` is provided, this overrides the default query name sent to the upstream server. The same logic applies to `options[:resource_class]`.
		def passthrough(resolver, options = {})
			query_name = options[:name] || name
			query_resource_class = options[:resource_class] || resource_class
			
			resolver.query(query_name, query_resource_class)
		end
		
		# Respond to the given query with a resource record. The arguments to this function depend on the `resource_class` requested. This function instantiates the resource class with the supplied arguments, and then passes it to {#append!}.
		#
		# e.g. For A records: `respond!("1.2.3.4")`, For MX records:  `respond!(10, Name.create("mail.blah.com"))`
		
		# The last argument can optionally be a hash of `options`. If `options[:resource_class]` is provided, it overrides the default resource class of transaction. Additional `options` are passed to {#append!}.
		#
		# See `Resolv::DNS::Resource` for more information about the various `resource_classes` available (http://www.ruby-doc.org/stdlib/libdoc/resolv/rdoc/index.html).
		def respond!(*args)
			append_question!
			
			options = args.last.kind_of?(Hash) ? args.pop : {}
			resource_class = options[:resource_class] || @resource_class
			
			if resource_class == nil
				raise ArgumentError.new("Could not instantiate resource #{resource_class}!")
			end
			
			@server.logger.info "Resource class: #{resource_class.inspect}"
			resource = resource_class.new(*args)
			@server.logger.info "Resource: #{resource.inspect}"
			
			add([resource], options)
		end
		
		# Append a list of resources.
		#
		# By default resources are appended to the `answers` section, but this can be changed by setting `options[:section]` to either `:authority` or `:additional`.
		#
		# The time-to-live (TTL) of the resources can be specified using `options[:ttl]` and defaults to `DEFAULT_TTL`.
		def add(resources, options = {})
			# Use the default options if provided:
			options = options.merge(@options)
			
			ttl = options[:ttl] || DEFAULT_TTL
			name = options[:name] || @question.to_s + "."
			
			section = (options[:section] || 'answer').to_sym
			method = "add_#{section}".to_sym
			
			resources.each do |resource|
				@server.logger.debug "#{method}: #{resource.inspect} #{resource.class::TypeValue} #{resource.class::ClassValue}"
				
				@response.send(method, name, ttl, resource)
			end
		end
		
		# This function indicates that there was a failure to resolve the given question. The single argument must be an integer error code, typically given by the constants in {Resolv::DNS::RCode}.
		#
		# The easiest way to use this function it to simply supply a symbol. Here is a list of the most commonly used ones:
		#
		# - `:NoError`: No error occurred.
		# - `:FormErr`: The incoming data was not formatted correctly.
		# - `:ServFail`: The operation caused a server failure (internal error, etc).
		# - `:NXDomain`: Non-eXistant Domain (domain record does not exist).
		# - `:NotImp`: The operation requested is not implemented.
		# - `:Refused`: The operation was refused by the server.
		# - `:NotAuth`: The server is not authoritive for the zone.
		#
		# See [RFC2929](http://www.rfc-editor.org/rfc/rfc2929.txt) for more information about DNS error codes (specifically, page 3).
		#
		# **This function will complete deferred transactions.**
		def fail!(rcode)
			append_question!
			
			if rcode.kind_of? Symbol
				@response.rcode = Resolv::DNS::RCode.const_get(rcode)
			else
				@response.rcode = rcode.to_i
			end
		end
		
		# @deprecated
		def failure!(*args)
			@server.logger.warn "failure! is deprecated, use fail! instead"
			
			fail!(*args)
		end
		
		# A helper method to process the transaction on the given server. Unless the transaction is deferred, it will {#succeed} on completion.
		def process
			@server.process(name, @resource_class, self)
		end
		
		protected
		
		# A typical response to a DNS request includes both the question and response. This helper appends the question unless it looks like the user is already managing that aspect of the response.
		def append_question!
			if @response.question.size == 0
				@response.add_question(@question, @resource_class)
			end
		end
	end
end
