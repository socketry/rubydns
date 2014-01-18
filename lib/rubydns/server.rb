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

require 'rubydns/transaction'
require 'rubydns/extensions/logger'

module RubyDNS
	
	# This class provides the core of the DSL. It contains a list of rules which
	# are used to match against incoming DNS questions. These rules are used to
	# generate responses which are either DNS resource records or failures.
	class Server
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
			
			def call(server, name, resource_class, *args)
				unless match(name, resource_class)
					server.logger.debug "Resource class #{resource_class} failed to match #{@pattern[1].inspect}!"
					
					return false
				end
				
				# Does this rule match against the supplied name?
				case @pattern[0]
				when Regexp
					match_data = @pattern[0].match(name)
					
					if match_data
						server.logger.debug "Regexp pattern matched with #{match_data.inspect}."
						
						@callback[*args, match_data]
						
						return true
					end
				when String
					if @pattern[0] == name
						server.logger.debug "String pattern matched."
						
						@callback[*args]
						
						return true
					end
				else
					if (@pattern[0].call(name, resource_class) rescue false)
						server.logger.debug "Callable pattern matched."
						
						@callback[*args]
						
						return true
					end
				end
				
				server.logger.debug "No pattern matched."
				
				# We failed to match the pattern.
				return false
			end
			
			def to_s
				@pattern.inspect
			end
		end
		
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

		attr_accessor :logger

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
			@rules << Rule.new(pattern, block)
		end

		# Register a named event which may be invoked later using #fire
		#   on(:start) do |server|
		#     RExec.change_user(RUN_AS)
		#   end
		def on(event_name, &block)
			@events[event_name] = block
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
			@otherwise = block
		end
		
		# If you match a rule, but decide within the rule that it isn't the correct one to use, you can call
		# `next!` to evaluate the next rule - in other words, to continue falling down through the list of rules.
		def next!
			throw :next
		end
		
		# Give a name and a record type, try to match a rule and use it for
		# processing the given arguments.
		#
		# If a rule returns false, it is considered that the rule failed and
		# futher matching is carried out.
		def process(name, resource_class, *args)
			@logger.debug "Searching for #{name} #{resource_class.name}"
			
			@rules.each do |rule|
				@logger.debug "Checking rule #{rule}..."
				
				catch (:next) do
					# If the rule returns true, we assume that it was successful and no further rules need to be evaluated.
					return if rule.call(self, name, resource_class, *args)
				end
			end
			
			if @otherwise
				@otherwise.call(*args)
			else
				@logger.warn "Failed to handle #{name} #{resource_class.name}!"
			end
		end
		
		
		def defer(&block)
			fiber = Fiber.current
			
			yield(fiber)
			
			Fiber.yield
		end
		
		# Process an incoming DNS message. Returns a serialized message to be
		# sent back to the client.
		def process_query(query, options = {}, &block)
			# Setup answer
			answer = Resolv::DNS::Message::new(query.id)
			answer.qr = 1                 # 0 = Query, 1 = Response
			answer.opcode = query.opcode  # Type of Query; copy from query
			answer.aa = 1                 # Is this an authoritative response: 0 = No, 1 = Yes
			answer.rd = query.rd          # Is Recursion Desired, copied from query
			answer.ra = 0                 # Does name server support recursion: 0 = No, 1 = Yes
			answer.rcode = 0              # Response code: 0 = No errors
			
			Fiber.new do
				transaction = nil
				
				begin
					query.question.each do |question, resource_class|
						@logger.debug "Processing question #{question} #{resource_class}..."
				
						transaction = Transaction.new(self, query, question, resource_class, answer, options)
						
						transaction.process
					end
				rescue
					@logger.error "Exception thrown while processing #{transaction}!"
					RubyDNS.log_exception(@logger, $!)
				
					answer.rcode = Resolv::DNS::RCode::ServFail
				end
			
				yield answer
			end.resume
		end
	end
end
