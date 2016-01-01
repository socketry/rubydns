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

require_relative 'transport'

module RubyDNS
	class GenericHandler
		include Celluloid::IO
		
		def initialize(server)
			@server = server
			@logger = @server.logger || Celluloid.logger
		end
		
		def error_response(query = nil, code = Resolv::DNS::RCode::ServFail)
			# Encoding may fail, so we need to handle this particular case:
			server_failure = Resolv::DNS::Message::new(query ? query.id : 0)
			
			server_failure.qr = 1
			server_failure.opcode = query ? query.opcode : 0
			server_failure.aa = 1
			server_failure.rd = 0
			server_failure.ra = 0

			server_failure.rcode = code

			# We can't do anything at this point...
			return server_failure
		end
		
		def process_query(data, options)
			@logger.debug "<> Receiving incoming query (#{data.bytesize} bytes) to #{self.class.name}..."
			query = nil

			begin
				query = RubyDNS::decode_message(data)
				
				return @server.process_query(query, options)
			rescue Celluloid::ResumableError
				# Celluloid terminates tasks, we may be stuck in a task when the server is terminated. We don't want to reply to the client in this case, because the server is being terminated. It might be an option to return a server failure
				raise
			rescue StandardError => error
				@logger.error "<> Error processing request: #{error.inspect}!"
				RubyDNS::log_exception(@logger, error)
				
				return error_response(query)
			end
		end
	end
	
	# Handling incoming UDP requests, which are single data packets, and pass them on to the given server.
	class UDPSocketHandler < GenericHandler
		include Celluloid::IO
		
		def initialize(server, socket)
			super(server)
			
			@socket = socket
			
			async.run
		end
		
		def run
			loop { handle_connection }
		end
		
		def respond(input_data, remote_host, remote_port)
			options = {peer: remote_host, port: remote_port, proto: :udp}
			
			response = process_query(input_data, options)
			
			output_data = response.encode
			
			@logger.debug "<#{response.id}> Writing #{output_data.bytesize} bytes response to client via UDP..."
			
			if output_data.bytesize > UDP_TRUNCATION_SIZE
				@logger.warn "<#{response.id}>Response via UDP was larger than #{UDP_TRUNCATION_SIZE}!"
				
				# Reencode data with truncation flag marked as true:
				truncation_error = Resolv::DNS::Message.new(response.id)
				truncation_error.tc = 1
				
				output_data = truncation_error.encode
			end
			
			@socket.send(output_data, 0, remote_host, remote_port)
		rescue IOError => error
			@logger.warn "<> UDP response failed: #{error.inspect}!"
		rescue EOFError => error
			@logger.warn "<> UDP session ended prematurely: #{error.inspect}!"
		rescue DecodeError
			@logger.warn "<> Could not decode incoming UDP data!"
		end
		
		def handle_connection
			# @logger.debug "Waiting for incoming UDP packet #{@socket.inspect}..."
			
			input_data, (_, remote_port, remote_host) = @socket.recvfrom(UDP_TRUNCATION_SIZE, 0)
			
			async.respond(input_data, remote_host, remote_port)
		rescue IOError => error
			@logger.warn "<> UDP connection failed: #{error.inspect}!"
		rescue EOFError => error
			@logger.warn "<> UDP session ended prematurely!"
		end
	end
	
	class UDPHandler < UDPSocketHandler
		def initialize(server, host, port)
			family = RubyDNS::address_family(host)
			socket = UDPSocket.new(family)
			
			socket.bind(host, port)
			
			super(server, socket)
		end
		
		finalizer :finalize
		
		def finalize
			@socket.close if @socket
		end
	end
	
	class TCPSocketHandler < GenericHandler
		def initialize(server, socket)
			super(server)
			
			@socket = socket
			
			async.run
		end
		
		def run
			loop { async.handle_connection @socket.accept }
		end
		
		def handle_connection(socket)
			_, remote_port, remote_host = socket.peeraddr
			options = {peer: remote_host, port: remote_port, proto: :tcp}
			
			input_data = StreamTransport.read_chunk(socket)
			
			response = process_query(input_data, options)
			
			length = StreamTransport.write_message(socket, response)
			
			@logger.debug "<#{response.id}> Wrote #{length} bytes via TCP..."
		rescue EOFError => error
			@logger.warn "<> TCP session ended prematurely!"
		rescue DecodeError
			@logger.warn "<> Could not decode incoming TCP data!"
		ensure
			socket.close
		end
	end
	
	class TCPHandler < TCPSocketHandler
		def initialize(server, host, port)
			socket = TCPServer.new(host, port)
			
			super(server, socket)
		end
		
		finalizer :finalize
		
		def finalize
			@socket.close if @socket
		end
	end
end
