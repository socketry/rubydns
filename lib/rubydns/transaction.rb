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

module RubyDNS

	# This class provides all details of a single DNS question and answer. This
	# is used by the DSL to provide DNS related functionality.
	class Transaction
		def initialize(server, query, question, resource_class, answer)
			@server = server
			@query = query
			@question = question
			@resource_class = resource_class
			@answer = answer
			
			@original_resource_class = nil
			@question_appended = false
		end

		# The resource_class that was requested. This is typically used to generate a
		# response.
		attr :resource_class
		
		# The original resource_class that was requested. Only use in case of ANY requests.
		attr_accessor :original_resource_class

		# The incoming query which is a set of questions.
		attr :query
		
		# The question that this transaction represents.
		attr :question
		
		# The current full answer to the incoming query.
		attr :answer
		
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
		def append_query!(name, resource_class = nil)
			Transaction.new(@server, @query, name, resource_class || @resource_class, @answer).process
		end

		def process
			@server.process(name, @resource_class, self)
		end

		# Use the given resolver to respond to the question. The default functionality is
		# implemented by passthrough, and if a reply is received, it will be merged with the
		# answer for this transaction.
		#
		# If a block is supplied, this function yields with the reply and reply_name if
		# successful. This could be used, for example, to update a cache or modify the
		# reply.
		def passthrough! (resolver, options = {}, &block)
			passthrough(resolver, options) do |reply, reply_name|
				if block_given?
					yield reply, reply_name
				end
				
				@answer.merge!(reply)
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
		def passthrough (resolver, options = {}, &block)
			if @query.rd || options[:force]
				reply, reply_name = resolver.query(name, resource_class)
				
				if reply
					yield reply, reply_name
				else
					failure!(:NXDomain)
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
		# 
		# This function can be used to supply multiple responses to a given question.
		# For example, each argument is expected to be an instantiated resource from
		# <tt>Resolv::DNS::Resource</tt> module.
		def append! (*resources)
			append_question!

			options = resources.last.kind_of?(Hash) ? resources.pop.dup : {}
			options[:ttl] ||= 16000
			options[:name] ||= @question.to_s + "."

			resources.each do |resource|
				@server.logger.debug "add_answer: #{resource.inspect} #{resource.class::TypeValue} #{resource.class::ClassValue}"
				@answer.add_answer(options[:name], options[:ttl], resource)
			end

			# Raise an exception if there was something wrong with the resource
			@answer.encode

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

			true
		end

		protected
		def append_question!
			if @answer.question.size == 0
				@aboutnswer.add_question(@question, @original_resource_class || @resource_class) unless @question_appended
			end
		end
	end
end