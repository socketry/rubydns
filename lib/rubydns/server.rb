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

require 'celluloid/io'

require_relative 'transaction'
require_relative 'logger'

module RubyDNS
	class UDPSocketWrapper < Celluloid::IO::UDPSocket
		def initialize(socket)
			@socket = socket
		end
	end
	
	class TCPServerWrapper < Celluloid::IO::TCPServer
		def initialize(server)
			@server = server
		end
	end
	
	class Server
		include Celluloid::IO
		
		finalizer :shutdown
		
		# The default server interfaces
		DEFAULT_INTERFACES = [[:udp, "0.0.0.0", 53], [:tcp, "0.0.0.0", 53]]
		
		# Instantiate a server with a block
		#
		#	server = Server.new do
		#		match(/server.mydomain.com/, IN::A) do |transaction|
		#			transaction.respond!("1.2.3.4")
		#		end
		#	end
		#
		def initialize(options = {})
			@handlers = []
			
			@logger = options[:logger] || Celluloid.logger
			@interfaces = options[:listen] || DEFAULT_INTERFACES
			
			@origin = options[:origin] || '.'
		end

		# Records are relative to this origin:
		attr_accessor :origin

		attr_accessor :logger

		# Fire the named event as part of running the server.
		def fire(event_name)
		end
		
		def shutdown
			fire(:stop)
		end
		
		# Give a name and a record type, try to match a rule and use it for processing the given arguments.
		def process(name, resource_class, transaction)
			raise NotImplementedError.new
		end
		
		# Process an incoming DNS message. Returns a serialized message to be sent back to the client.
		def process_query(query, options = {}, &block)
			start_time = Time.now
			
			# Setup response
			response = Resolv::DNS::Message::new(query.id)
			response.qr = 1                 # 0 = Query, 1 = Response
			response.opcode = query.opcode  # Type of Query; copy from query
			response.aa = 1                 # Is this an authoritative response: 0 = No, 1 = Yes
			response.rd = query.rd          # Is Recursion Desired, copied from query
			response.ra = 0                 # Does name server support recursion: 0 = No, 1 = Yes
			response.rcode = 0              # Response code: 0 = No errors
			
			transaction = nil
			
			begin
				query.question.each do |question, resource_class|
					begin
						question = question.without_origin(@origin)
						
						@logger.debug {"<#{query.id}> Processing question #{question} #{resource_class}..."}
						
						transaction = Transaction.new(self, query, question, resource_class, response, options)
						
						transaction.process
					rescue Resolv::DNS::OriginError
						# This is triggered if the question is not part of the specified @origin:
						@logger.debug {"<#{query.id}> Skipping question #{question} #{resource_class} because #{$!}"}
					end
				end
			rescue Celluloid::ResumableError
				raise
			rescue StandardError => error
				@logger.error "<#{query.id}> Exception thrown while processing #{transaction}!"
				RubyDNS.log_exception(@logger, error)
			
				response.rcode = Resolv::DNS::RCode::ServFail
			end
			
			end_time = Time.now
			@logger.debug {"<#{query.id}> Time to process request: #{end_time - start_time}s"}
			
			return response
		end
		
		#
		# By default the server runs on port 53, both TCP and UDP, which is usually a priviledged port and requires root access to bind. You can change this by specifying `options[:listen]` which should contain an array of `[protocol, interface address, port]` specifications.
		# 
		#	INTERFACES = [[:udp, "0.0.0.0", 5300]]
		#	RubyDNS::run_server(:listen => INTERFACES) do
		#		...
		#	end
		#
		# You can specify already connected sockets if need be:
		#
		#   socket = UDPSocket.new; socket.bind("0.0.0.0", 53)
		#   Process::Sys.setuid(server_uid)
		#   INTERFACES = [socket]
		#
		def run
			@logger.info "Starting RubyDNS server (v#{RubyDNS::VERSION})..."
			
			fire(:setup)
			
			# Setup server sockets
			@interfaces.each do |spec|
				if spec.is_a?(BasicSocket)
					spec.do_not_reverse_lookup
					protocol = spec.getsockopt(Socket::SOL_SOCKET, Socket::SO_TYPE).unpack("i")[0]
					ip = spec.local_address.ip_address
					port = spec.local_address.ip_port
					
					case protocol
					when Socket::SOCK_DGRAM
						@logger.info "<> Attaching to pre-existing UDP socket #{ip}:#{port}"
						link UDPSocketHandler.new(self, UDPSocketWrapper.new(spec))
					when Socket::SOCK_STREAM
						@logger.info "<> Attaching to pre-existing TCP socket #{ip}:#{port}"
						link TCPSocketHandler.new(self, TCPServerWrapper.new(spec))
					else
						raise ArgumentError.new("Unknown socket protocol: #{protocol}")
					end
				elsif spec[0] == :udp
					@logger.info "<> Listening on #{spec.join(':')}"
					link UDPHandler.new(self, spec[1], spec[2])
				elsif spec[0] == :tcp
					@logger.info "<> Listening on #{spec.join(':')}"
					link TCPHandler.new(self, spec[1], spec[2])
				else
					raise ArgumentError.new("Invalid connection specification: #{spec.inspect}")
				end
			end
			
			fire(:start)
		end
	end
	
	# Provides the core of the RubyDNS domain-specific language (DSL). It contains a list of rules which are used to match against incoming DNS questions. These rules are used to generate responses which are either DNS resource records or failures.
	class RuleBasedServer < Server
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
		
		# Don't wrap the block going into initialize.
		execute_block_on_receiver :initialize
		
		# Instantiate a server with a block
		#
		#	server = Server.new do
		#		match(/server.mydomain.com/, IN::A) do |transaction|
		#			transaction.respond!("1.2.3.4")
		#		end
		#	end
		#
		def initialize(options = {}, &block)
			super(options)
			
			@events = {}
			@rules = []
			@otherwise = nil
			
			if block_given?
				instance_eval(&block)
			end
		end

		attr_accessor :logger

		# This function connects a pattern with a block. A pattern is either a String or a Regex instance. Optionally, a second argument can be provided which is either a String, Symbol or Array of resource record types which the rule matches against.
		# 
		#	match("www.google.com")
		#	match("gmail.com", IN::MX)
		#	match(/g?mail.(com|org|net)/, [IN::MX, IN::A])
		#
		def match(*pattern, &block)
			@rules << Rule.new(pattern, block)
		end

		# Register a named event which may be invoked later using #fire
		#
		#	on(:start) do |server|
		#		Process::Daemon::Permissions.change_user(RUN_AS)
		#	end
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
			@logger.debug {"<#{transaction.query.id}> Searching for #{name} #{resource_class.name}"}
			
			@rules.each do |rule|
				@logger.debug {"<#{transaction.query.id}> Checking rule #{rule}..."}
				
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
