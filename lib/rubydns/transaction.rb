# Copyright (c) 2009 Samuel Williams. Released under the GNU GPLv3.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

module RubyDNS

	# Turn a symbol or string name into a resource class. For example,
	# convert <tt>:A</tt> into <tt>Resolv::DNS::Resource::IN::A</tt>
	# Provide a second argument (top) to specify a namespace where
	# klass should be resolved, e.g. <tt>Resolv::DNS::Resource::IN</tt>.
	def self.lookup_resource_class(klass, top = nil)
		return nil if klass == nil

		if Symbol === klass
			klass = klass.to_s
		end

		if String === klass
			top ||= Resolv::DNS::Resource::IN
			klass = self.find_constant(top, klass.split("::"))
		end

		return klass
	end

	def self.constantize(names)
		top = Object

		names.each do |name|
			if top.const_defined?(name)
				top = top.const_get(name)
			else
				return nil
			end
		end

		top
	end

	def self.find_constant(top, klass)
		names = top.name.split("::")

		while names.size
			object = self.constantize(names + klass)

			return object if object

			names.pop
		end

		return nil
	end

	# This class provides all details of a single DNS question and answer. This
	# is used by the DSL to provide DNS related functionality.
	class Transaction
		def initialize(server, query, question, resource_class, answer)
			@server = server
			@query = query
			@question = question
			@resource_class = resource_class
			@answer = answer

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

		# Return the type of record (eg. <tt>A</tt>, <tt>MX</tt>) as a <tt>String</tt>.
		def record_type
			@resource_class.name.split("::").last
		end

		# Tries to find a resource class within the current resource category, which is
		# typically (but not always) <tt>IN</tt>. Uses the requested resource class as
		# a starting point.
		def lookup_resource_class(klass)
			return RubyDNS::lookup_resource_class(klass, @resource_class)
		end

		# Return the name of the question, which is typically the requested hostname.
		def name
			@question.to_s
		end

		# Suitable for debugging purposes
		def to_s
			"#{name} #{record_type}"
		end

		# Run a new query through the rules with the given name and resource type. The
		# results of this query are appended to the current transactions <tt>answer</tt>.
		def append_query!(name, resource_class = nil)
			Transaction.new(@server, @query, name, lookup_resource_class(resource_class) || @resource_class, @answer).process
		end

		def process
			@server.process(name, record_type, self)
		end

		# Use the given resolver to respond to the question. This will <tt>query</tt>
		# the resolver and <tt>merge!</tt> the answer if one is received. If recursion is
		# not requested, the result is <tt>failure!(:Refused)</tt>. If the resolver does
		# not respond, the result is <tt>failure!(:NXDomain)</tt>
		#
		# If a block is supplied, this function yields with the reply and reply_name if
		# successful. This could be used, for example, to update a cache.
		def passthrough! (resolver, &block)
			# Were we asked to recursively find this name?
			if @query.rd
				reply, reply_name = resolver.query(name, resource_class)

				if reply
					if block_given?
						ret = yield(reply, reply_name)
						reply = ret if ret.is_a?(Resolv::DNS::Message)
					end
					@answer.merge!(reply)
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
			resource_class = lookup_resource_class(options[:resource_class]) || @resource_class

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
				@server.logger.info "add_answer: #{resource.inspect} #{resource.class::TypeValue} #{resource.class::ClassValue}"
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
				@answer.add_question(@question, @resource_class) unless @question_appended
			end
		end
	end
end
