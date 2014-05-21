# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'message'
require_relative 'binary_string'

require 'securerandom'
require 'celluloid/io'

module RubyDNS
	class InvalidProtocolError < StandardError
	end
	
	class InvalidResponseError < StandardError
	end
	
	class ResolutionFailure < StandardError
	end
	
	class Resolver
		include Celluloid::IO
		
		# Servers are specified in the same manor as options[:listen], e.g.
		#   [:tcp/:udp, address, port]
		# In the case of multiple servers, they will be checked in sequence.
		def initialize(servers, options = {})
			@servers = servers
			
			@options = options
			
			@logger = options[:logger]
		end

		# Provides the next sequence identification number which is used to keep track of DNS messages.
		def next_id!
			# Using sequential numbers for the query ID is generally a bad thing because over UDP they can be spoofed. 16-bits isn't hard to guess either, but over UDP we also use a random port, so this makes effectively 32-bits of entropy to guess per request.
			SecureRandom.random_number(2**16)
		end

		# Look up a named resource of the given resource_class.
		def query(name, resource_class = Resolv::DNS::Resource::IN::A)
			message = Resolv::DNS::Message.new(next_id!)
			message.rd = 1
			message.add_question name, resource_class
			
			send_message(message)
		end
		
		# Yields a list of `Resolv::IPv4` and `Resolv::IPv6` addresses for the given `name` and `resource_class`.
		def addresses_for(name, resource_class = Resolv::DNS::Resource::IN::A)
			response = query(name, resource_class)
			# Resolv::DNS::Name doesn't retain the trailing dot.
			name = name.sub(/\.$/, '')
			
			case response
			when Message
				response.answer.select{|record| record[0].to_s == name}.collect{|record| record[2].address}
			else
				nil
			end
		end

		def send_message(message)
			request = Request.new(message, @servers, @options)
			
			timer = after(@options[:timeout] || 0.5) do 
				@logger.debug "[#{message.id}] Request timed out!" if @logger
				
				request.cancel!
			end
			
			response = nil
			
			loop do
				timer.reset
				
				begin
					response = request.try_next_server!
					
					if response.tc != 0
						@logger.warn "[#{message.id}] Received truncated response!" if @logger
					elsif response.id != message.id
						@logger.warn "[#{message.id}] Received response with incorrect message id: #{response.id}" if @logger
					else
						@logger.debug "[#{message.id}] Received valid response #{response.inspect}" if @logger
					
						return response
					end
				rescue IOError
					@logger.warn "[#{message.id}] Error while reading from network!" if @logger
				end
			end
		ensure
			timer.cancel
		end
		
		private
		
		# Manages a single DNS question message across one or more servers.
		class Request
			def initialize(message, servers, options = {}, &block)
				@message = message
				@packet = message.encode
				
				@servers = servers.dup
				
				# We select the protocol based on the size of the data:
				if @packet.bytesize > UDP_TRUNCATION_SIZE
					@servers.delete_if{|server| server[0] == :udp}
				end
				
				@logger = options[:logger]
			end
			
			attr :message
			attr :packet
			attr :logger
			
			def servers_available?
				@servers.size > 0
			end
			
			def try_next_server!
				if @servers.size > 0
					server = @servers.shift
					
					@logger.debug "[#{@message.id}] Sending request to server #{server.inspect}" if @logger
					
					# We make requests one at a time to the given server, naturally the servers are ordered in terms of priority.
					case server[0]
					when :udp
						response = try_udp_server(server[1], server[2])
					when :tcp
						response = try_tcp_server(server[1], server[2])
					else
						raise InvalidProtocolError.new(server)
					end
				else
					raise ResolutionFailure.new("No available servers responded to the request.")
				end
			end
			
			def cancel!
				finish_request
			end
			
			private
			
			# Closes any connections and cancels any timeout.
			def finish_request
				# Cancel an existing request if it is in flight:
				if @socket
					@socket.close
					@socket = nil
				end
			end
			
			def try_udp_server(host, port)
				@socket = Celluloid::IO::UDPSocket.new
				@socket.send(self.packet, 0, host, port)
				
				data, (_, remote_port) = @socket.recvfrom(UDP_TRUNCATION_SIZE)
				# Need to check host, otherwise security issue.
				
				if port != remote_port
					raise InvalidResponseError.new("Data was not received from correct remote port (#{port} != #{remote_port})")
				end
				
				message = RubyDNS::decode_message(data)
			ensure
				finish_request
			end
			
			def try_tcp_server(host, port)
				@socket = Celluloid::IO::TCPSocket.new(host, port)
				
				data = self.packet
				@socket.send([data.bytesize].pack('n'), 0)
				@socket.send(data, 0)
				
				buffer = BinaryStringIO.new
				length = 2
				
				while buffer.size < length
					data = @socket.recv(UDP_TRUNCATION_SIZE)
					buffer.write(data)
					
					if buffer.size > 2
						length += buffer.string.byteslice(0, 2).unpack('n')[0]
					end
				end
				
				data = buffer.string.byteslice(2, length - 2)
				message = RubyDNS::decode_message(data)
			ensure
				finish_request
			end
		end
	end
end
