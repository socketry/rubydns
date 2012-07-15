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

require 'rubydns/transaction'

module RubyDNS
	
	# This class provides the core of the DSL. It contains a list of rules which
	# are used to match against incoming DNS questions. These rules are used to
	# generate responses which are either DNS resource records or failures.
	class Server
		# Instantiate a server with a block
		#
		#   server = Server.new do
		#     match(/server.mydomain.com/, IN::A) do |transaction|
		#       transaction.respond!("1.2.3.4")
		#     end
		#   end
		#
		def initialize(&block)
			@events = {}
			@rules = []
			@otherwise = nil

			@logger = Logger.new($stderr)

			if block_given?
				instance_eval &block
			end
		end

		attr :logger, true

		# This function connects a pattern with a block. A pattern is either
		# a String or a Regex instance. Optionally, a second argument can be
		# provided which is either a String, Symbol or Array of resource record
		# types which the rule matches against.
		# 
		#   match("www.google.com")
		#   match("gmail.com", IN::MX)
		#   match(/g?mail.(com|org|net)/, [IN::MX, IN::A])
		#
		def match(*pattern, &block)
			@rules << [pattern, Proc.new(&block)]
		end

		# Register a named event which may be invoked later using #fire
		#   on(:start) do |server|
		#     RExec.change_user(RUN_AS)
		#   end
		def on(event_name, &block)
			@events[event_name] = Proc.new(&block)
		end
		
		# Fire the named event, which must have been registered using on.
		def fire(event_name)
			callback = @events[event_name]
			
			if callback
				callback.call(self)
			end
		end
		
		# Specify a default block to execute if all other rules fail to match.
		# This block is typially used to pass the request on to another server
		# (i.e. recursive request).
		#
		#   otherwise do |transaction|
		#     transaction.passthrough!($R)
		#   end
		#
		def otherwise(&block)
			@otherwise = Proc.new(&block)
		end

		# Give a name and a record type, try to match a rule and use it for
		# processing the given arguments.
		#
		# If a rule returns false, it is considered that the rule failed and
		# futher matching is carried out.
		def process(name, resource_class, *args)
			@logger.debug "Searching for #{name} #{resource_class.name}"

			@rules.each do |rule|
				@logger.debug "Checking rule #{rule[0].inspect}..."
				
				pattern = rule[0]

				# Match failed against resource_class?
				case pattern[1]
				when Class
					next unless pattern[1] == resource_class
					@logger.debug "Resource class #{resource_class.name} matched"
				when Array
					next unless pattern[1].include?(resource_class)
					@logger.debug "Resource class #{resource_class} matched #{pattern[1].inspect}"
				end

				# Match succeeded against name?
				case pattern[0]
				when Regexp
					match_data = pattern[0].match(name)
					if match_data
						@logger.debug "Query #{name} matched #{pattern[0].to_s} with result #{match_data.inspect}"
						if rule[1].call(match_data, *args)
							@logger.debug "Rule returned successfully"
							return
						end
					else
						@logger.debug "Query #{name} failed to match against #{pattern[0].to_s}"
					end
				when String
					if pattern[0] == name
						@logger.debug "Query #{name} matched #{pattern[0]}"
						if rule[1].call(*args)
							@logger.debug "Rule returned successfully"
							return
						end
					else
						@logger.debug "Query #{name} failed to match against #{pattern[0]}"
					end
				else
					if pattern[0].respond_to? :call
						if pattern[0].call(name)
							@logger.debug "Query #{name} matched #{pattern[0]}"
							if rule[1].call(*args)
								@logger.debug "Rule returned successfully"
								return
							end
						else
							@logger.debug "Query #{name} failed to match against #{pattern[0]}"
						end
					end
				end
			end

			if @otherwise
				@otherwise.call(*args)
			else
				@logger.warn "Failed to handle #{name} #{resource_class.name}!"
			end
		end

		# Process an incoming DNS message. Returns a serialized message to be
		# sent back to the client.
		def process_query(query, &block)
			# Setup answer
			answer = Resolv::DNS::Message::new(query.id)
			answer.qr = 1                 # 0 = Query, 1 = Response
			answer.opcode = query.opcode  # Type of Query; copy from query
			answer.aa = 1                 # Is this an authoritative response: 0 = No, 1 = Yes
			answer.rd = query.rd          # Is Recursion Desired, copied from query
			answer.ra = 0                 # Does name server support recursion: 0 = No, 1 = Yes
			answer.rcode = 0              # Response code: 0 = No errors

			query.each_question do |question, question_resource_class|    # There may be multiple questions per query
				resource_classes = if question_resource_class == Resolv::DNS::Resource::IN::ANY then
					resource_classes = [Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA, Resolv::DNS::Resource::IN::ANY, Resolv::DNS::Resource::IN::CNAME, Resolv::DNS::Resource::IN::HINFO, Resolv::DNS::Resource::IN::MINFO, Resolv::DNS::Resource::IN::MX, Resolv::DNS::Resource::IN::NS, Resolv::DNS::Resource::IN::PTR, Resolv::DNS::Resource::IN::SOA, Resolv::DNS::Resource::IN::TXT]
				else
					[question_resource_class]
				end

				resource_classes.each do |resource_class|
					transaction = Transaction.new(self, query, question, resource_class, answer)
					transaction.original_resource_class = question_resource_class

					begin
						transaction.process
					rescue
						@logger.error "Exception thrown while processing #{transaction}!"
						@logger.error "#{$!.class}: #{$!.message}"
						$!.backtrace.each { |at| @logger.error at }

						answer.rcode = Resolv::DNS::RCode::ServFail
					end
				end

				if block_given?
					yield answer
				else
					return answer
				end
			end
		end
	end
end
