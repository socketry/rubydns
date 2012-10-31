# Copyright (c) 2009, 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
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

require 'eventmachine'

module RubyDNS

	# This class provides all details of a single DNS question and answer. This
	# is used by the DSL to provide DNS related functionality.
	class Transaction
		include EventMachine::Deferrable
		
		def initialize(server, query, question, resource_class, answer, options = {})
			@server = server
			@query = query
			@question = question
			@resource_class = resource_class
			@answer = answer

			@options = options

			@deferred = false
			@question_appended = false
		end

		# The resource_class that was requested. This is typically used to generate a
		# response.
		attr :resource_class
		
		# The incoming query which is a set of questions.
		attr :query
		
		# The question that this transaction represents.
		attr :question
		
		# The current full answer to the incoming query.
		attr :answer
		
		# Any options or configuration associated with the given transaction.
		attr :options
		
		# Return the name of the question, which is typically the requested hostname.
		def name
			@question.to_s
		end

		# Suitable for debugging purposes
		def to_s
			"#{name} #{@resource_class.name}"
		end

		# Run a new query through the rules with the given name and resource type. The
		# results of this query are appended to the current transactions <tt>answer</tt>.
		def append_query!(name, resource_class = nil, options = {})
			Transaction.new(@server, @query, name, resource_class || @resource_class, @answer, options).process
		end

		def process(&finished)
			@server.process(name, @resource_class, self)

			unless @deferred
				succeed(self)
			end
		end

		def defer!
			@deferred = true
		end

		# Use the given resolver to respond to the question. The default functionality is
		# implemented by passthrough, and if a reply is received, it will be merged with the
		# answer for this transaction.
		#
		# If a block is supplied, this function yields with the reply and reply_name if
		# successful. This could be used, for example, to update a cache or modify the
		# reply.
		def passthrough!(resolver, options = {}, &block)
			passthrough(resolver, options) do |response|
				if block_given?
					yield response
				end
				
				@answer.merge!(response)
				
				succeed if @deferred
			end
			
			true
		end
		
		# Use the given resolver to respond to the question. If recursion is
		# not requested, the result is <tt>failure!(:Refused)</tt>. If the resolver does
		# not respond, the result is <tt>failure!(:NXDomain)</tt>
		#
		# If a block is supplied, this function yields with the reply and reply_name if
		# successful. This block is responsible for doing something useful with the reply,
		# such as merging it or conditionally discarding it.
		#
		# A second argument, options, provides some control over the passthrough process.
		# :force => true, ensures that the query will occur even if recursion is not requested.
		def passthrough(resolver, options = {}, &block)
			if @query.rd || options[:force]
				# Resolver is asynchronous, so we are now deferred:
				defer!

				resolver.query(name, resource_class) do |response|
					case response
					when RubyDNS::Message
						yield response
					when RubyDNS::ResolutionFailure
						failure!(:ServFail)
					else
						# This shouldn't ever happen, but if it does for some reason we shouldn't hang.
						fail(response)
					end
				end
			else
				failure!(:Refused)
			end
			
			true
		end

		# Respond to the given query with a resource record. The arguments to this
		# function depend on the <tt>resource_class</tt> requested. The last argument
		# can optionally be a hash of options.
		#
		# <tt>options[:resource_class]</tt>:: Override the default <tt>resource_class</tt>
		# <tt>options[:ttl]</tt>:: Specify the TTL for the resource
		# <tt>options[:name]</tt>:: Override the name (question) of the response.
		#
		# for A records:: <tt>respond!("1.2.3.4")</tt>
		# for MX records::  <tt>respond!("mail.blah.com", 10)</tt>
		#
		# This function instantiates the resource class with the supplied arguments, and
		# then passes it to <tt>append!</tt>.
		#
		# See <tt>Resolv::DNS::Resource</tt> for more information about the various 
		# <tt>resource_class</tt>s available. 
		# http://www.ruby-doc.org/stdlib/libdoc/resolv/rdoc/index.html
		def respond! (*data)
			options = data.last.kind_of?(Hash) ? data.pop : {}
			resource_class = options[:resource_class] || @resource_class
			
			if resource_class == nil
				raise ArgumentError, "Could not instantiate resource #{resource_class}!"
			end
			
			@server.logger.info "Resource class: #{resource_class.inspect}"
			resource = resource_class.new(*data)
			@server.logger.info "Resource: #{resource.inspect}"
			
			append!(resource, options)
		end

		# Append a given set of resources to the answer. The last argument can 
		# optionally be a hash of options.
		# 
		# <tt>options[:ttl]</tt>:: Specify the TTL for the resource
		# <tt>options[:name]</tt>:: Override the name (question) of the response.
		# <tt>options[:section]</tt>:: Specify whether the response should go in the `:answer`
		#                             `:authority` or `:additional` section.
		# 
		# This function can be used to supply multiple responses to a given question.
		# For example, each argument is expected to be an instantiated resource from
		# <tt>Resolv::DNS::Resource</tt> module.
		def append! (*resources)
			append_question!

			if resources.last.kind_of?(Hash)
				options = resources.pop
			else
				options = {}
			end

			# Use the default options if provided:
			options = options.merge(@options)

			options[:ttl] ||= 16000
			options[:name] ||= @question.to_s + "."
			
			method = ("add_" + (options[:section] || 'answer').to_s).to_sym

			resources.each do |resource|
				@server.logger.debug "#{method}: #{resource.inspect} #{resource.class::TypeValue} #{resource.class::ClassValue}"
				
				@answer.send(method, options[:name], options[:ttl], resource)
			end

			succeed if @deferred

			true
		end

		# This function indicates that there was a failure to resolve the given
		# question. The single argument must be an integer error code, typically
		# given by the constants in <tt>Resolv::DNS::RCode</tt>.
		#
		# The easiest way to use this function it to simply supply a symbol. Here is
		# a list of the most commonly used ones:
		#
		# <tt>:NoError</tt>:: No error occurred.
		# <tt>:FormErr</tt>::	The incoming data was not formatted correctly.
		# <tt>:ServFail</tt>:: The operation caused a server failure (internal error, etc).
		# <tt>:NXDomain</tt>:: Non-eXistant Domain (domain record does not exist).
		# <tt>:NotImp</tt>:: The operation requested is not implemented.
		# <tt>:Refused</tt>:: The operation was refused by the server.
		# <tt>:NotAuth</tt>:: The server is not authoritive for the zone.
		#
		# See http://www.rfc-editor.org/rfc/rfc2929.txt for more information
		# about DNS error codes (specifically, page 3).
		def failure! (rcode)
			append_question!

			if rcode.kind_of? Symbol
				@answer.rcode = Resolv::DNS::RCode.const_get(rcode)
			else
				@answer.rcode = rcode.to_i
			end

			# The transaction itself has completed, but contains a failure:
			succeed(rcode) if @deferred

			true
		end

		def append_question!
			if @answer.question.size == 0
				@answer.add_question(@question, @resource_class) unless @question_appended
			end
		end
	end
end
