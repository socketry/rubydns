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
		finalizer :finalize
		
		def initialize(server)
			@server = server
			@logger = @server.logger || Celluloid.logger
			
			async.run
		end
		
		def finalize
			@socket.close if @socket
		end
		
		def run
		end
		
		def process_query(data, options)
			@logger.debug "<> Receiving incoming query (#{data.bytesize} bytes)..."
			query = nil

			begin
				query = RubyDNS::decode_message(data)

				return @server.process_query(query, options)
			rescue Exception => error
				@logger.error "<> Error processing request!"
				@logger.error "<> #{error.class}: #{error.message}"

				error.backtrace.each { |line| @logger.error line }

				# Encoding may fail, so we need to handle this particular case:
				server_failure = Resolv::DNS::Message::new(query ? query.id : 0)
				server_failure.qr = 1
				server_failure.opcode = query ? query.opcode : 0
				server_failure.aa = 1
				server_failure.rd = 0
				server_failure.ra = 0

				server_failure.rcode = Resolv::DNS::RCode::ServFail

				# We can't do anything at this point...
				return server_failure
			end
		end
	end
	
	# Handling incoming UDP requests, which are single data packets, and pass them on to the given server.
	class UDPHandler < GenericHandler
		include Celluloid::IO
		
		def initialize(server, host, port)
			super(server)
			
			@socket = UDPSocket.new
			@socket.bind(host, port)
		end
		
		def run
			loop { handle_connection }
		end
		
		def respond(input_data, remote_host, remote_port)
			options = {peer: remote_host}
			
			answer = process_query(input_data, options)
			
			output_data = answer.encode
			
			@logger.debug "<#{answer.id}> Writing response to client (#{output_data.bytesize} bytes) via UDP..."
			
			if output_data.bytesize > UDP_TRUNCATION_SIZE
				@logger.warn "<#{answer.id}>Response via UDP was larger than #{UDP_TRUNCATION_SIZE}!"
				
				# Reencode data with truncation flag marked as true:
				truncation_error = Resolv::DNS::Message.new(answer.id)
				truncation_error.tc = 1
				
				output_data = truncation_error.encode
			end
			
			@socket.send(output_data, 0, remote_host, remote_port)
		rescue EOFError => error
			@logger.warn "<> UDP session ended prematurely!"
		end
		
		def handle_connection
			# @logger.debug "Waiting for incoming UDP packet #{@socket.inspect}..."
			
			input_data, (_, remote_port, remote_host) = @socket.recvfrom(UDP_TRUNCATION_SIZE)
			
			async.respond(input_data, remote_host, remote_port)
		rescue EOFError => error
			@logger.warn "<> UDP session ended prematurely!"
		end
	end
	
	class TCPHandler < GenericHandler
		def initialize(server, host, port)
			super(server)
			
			@socket = TCPServer.new(host, port)
		end
		
		def run
			# @logger.debug "Waiting for incoming TCP connections #{@socket.inspect}..."
			loop { async.handle_connection @socket.accept }
		end
		
		def handle_connection(socket)
			_, remote_port, remote_host = socket.peeraddr
			options = {peer: remote_host}
			
			input_data = StreamTransport.read_chunk(socket)
			
			answer = process_query(input_data, options)
			
			length = StreamTransport.write_message(socket, answer)
			
			@logger.debug "<#{answer.id}> Wrote #{length} bytes via TCP..."
		rescue EOFError => error
			@logger.warn "<> TCP session ended prematurely!"
		rescue Resolv::DNS::DecodeError
			@logger.warn "<> Could not decode incoming data!"
		ensure
			socket.close
		end
	end
end
