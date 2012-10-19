
require 'rubydns'
require 'eventmachine'
require 'resolv'

module RubyDNS
	# The DNS message container.
	Message = Resolv::DNS::Message
	
	class InvalidProtocolError < StandardError
	end
	
	class ResolutionFailure < StandardError
	end
	
	class Resolver
		# Servers are specified in the same manor as options[:listen], e.g.
		#   [:tcp/:udp, address, port]
		# In the case of multiple servers, they will be checked in sequence.
		def initialize(servers, options = {})
			@servers = servers
			@sequence = 0
			
			@options = options
		end

		# Provides the next sequence identification number which is used to keep track of DNS messages.
		def next_id!
			return (@sequence += 1)
		end

		# Look up a named resource of the given resource_class.
		def query(name, resource_class = Resolv::DNS::Resource::IN::A, &block)
			message = Resolv::DNS::Message.new(next_id!)
			message.rd = 1
			message.add_question name, resource_class
			
			Request.fetch(message, @servers, @options, &block)
		end

		# Manages a single DNS question message across one or more servers.
		class Request
			include EventMachine::Deferrable
			
			def self.fetch(*args)
				request = self.new(*args)
				
				request.callback do |message|
					yield message
				end
				
				request.errback do |error|
					yield error
				end
				
				request.run!
			end
			
			def initialize(message, servers, options = {}, &block)
				@message = message
				@packet = message.encode
				
				@servers = servers.dup
				
				# We select the protocol based on the size of the data:
				if @packet.bytesize > UDP_TRUNCATION_SIZE
					@servers.delete_if{|server| server[0] == :udp}
				end
				
				# Measured in seconds:
				@timeout = options[:timeout] || 5
			end
			
			attr :message
			attr :packet
			
			def run!
				try_next_server!
			end
			
			def process_response!(response)
				if response.tc != 0
					# We hardcode this behaviour for now.
					try_next_server!
				else
					succeed response
				end
			end
			
			private
			
			def try_next_server!
				if @request
					@request.close_connection
					@request = nil
				end
				
				if @servers.size > 0
					@server = @servers.shift
					
					# We make requests one at a time to the given server, naturally the servers are ordered in terms of priority.
					case @server[0]
					when :udp
						@request = UDPRequestHandler.open(@server[1], @server[2], self)
					when :tcp
						@request = TCPRequestHandler.open(@server[1], @server[2], self)
					else
						raise InvalidProtocolError.new(@server)
					end
					
					# Setting up the timeout...
					EventMachine::Timer.new(@timeout) do
						try_next_server!
					end
				else
					fail ResolutionFailure.new("No available servers responded to the request.")
				end
			end
			
			module UDPRequestHandler
				def self.open(host, port, request)
					# Open a datagram socket... EventMachine doesn't support connected datagram sockets, so we have to cheat a bit:
					EventMachine::open_datagram_socket('', 0, self, request, host, port)
				end
				
				def initialize(request, host, port)
					@request = request
					@host = host
					@port = port
				end
				
				def post_init
					# Sending question to remote DNS server...
					send_datagram(@request.packet, @host, @port)
				end
				
				def receive_data(data)
					# Receiving response from remote DNS server...
					message = Resolv::DNS::Message.decode(data)
					
					# The message id must match, and it can't be truncated:
					if message.id == @request.message.id
						@request.process_response!(message)
					end
				end
			end
			
			module TCPRequestHandler
				def self.open(host, port, request)
					EventMachine::connect(host, port, TCPRequestHandler, request)
				end
				
				def initialize(request)
					@request = request
					@buffer = StringIO.new
					@length = nil
				end
				
				def post_init
					data = @request.packet
					
					send_data([data.bytesize].pack('n'))
					send_data data
				end
				
				def receive_data(data)
					# We buffer data until we've received the entire packet:
					@buffer.write(data)

					if @length == nil
						if @buffer.size > 2
							@length = @buffer.string.byteslice(0, 2).unpack('n')[0]
						end
					end

					if @buffer.size == (@length + 2)
						data = @buffer.string.byteslice(2, @length)
						
						message = Resolv::DNS::Message.decode(data)
						
						if message.id == @request.message.id
							@request.process_response!(message)
						end
					elsif @buffer.size > (@length + 2)
						@request.try_next_server!
					end
				end
			end
		end
	end
end