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

require 'rubydns/message'
require 'rubydns/binary_string'

module RubyDNS
	# @returns the [port, ip address] of the given connection.
	def self.get_peer_details(connection)
		Socket.unpack_sockaddr_in(connection.get_peername)
	end
	
	# Handling incoming UDP requests, which are single data packets, and pass them on to the given server.
	module UDPHandler
		def initialize(server)
			@server = server
		end
		
		# Process a packet of data with the given server. If an exception is thrown, a failure message will be sent back.
		def self.process(server, data, options = {}, &block)
			server.logger.debug "Receiving incoming query (#{data.bytesize} bytes)..."
			query = nil

			begin
				query = RubyDNS::decode_message(data)

				return server.process_query(query, options, &block)
			rescue => error
				server.logger.error "Error processing request!"
				server.logger.error "#{error.class}: #{error.message}"

				error.backtrace.each { |at| server.logger.error at }

				# Encoding may fail, so we need to handle this particular case:
				server_failure = Resolv::DNS::Message::new(query ? query.id : 0)
				server_failure.qr = 1
				server_failure.opcode = query ? query.opcode : 0
				server_failure.aa = 1
				server_failure.rd = 0
				server_failure.ra = 0

				server_failure.rcode = Resolv::DNS::RCode::ServFail

				# We can't do anything at this point...
				yield server_failure
			end
		end
		
		def receive_data(data)
			peer_port, peer_ip = RubyDNS::get_peer_details(self)
			options = {:peer => peer_ip}
			
			UDPHandler.process(@server, data, options) do |answer|
				data = answer.encode
				
				@server.logger.debug "Writing response to client (#{data.bytesize} bytes) via UDP..."
				
				if data.bytesize > UDP_TRUNCATION_SIZE
					@server.logger.warn "Response via UDP was larger than #{UDP_TRUNCATION_SIZE}!"
					
					# Reencode data with truncation flag marked as true:
					truncation_error = Resolv::DNS::Message.new(answer.id)
					truncation_error.tc = 1
					
					data = truncation_error.encode
				end
				
				# We explicitly use the ip and port given, because we found that send_data was unreliable in a callback.
				self.send_datagram(data, peer_ip, peer_port)
			end
		end
	end
	
	class LengthError < StandardError
	end
	
	module TCPHandler
		def initialize(server)
			@server = server
			
			@buffer = BinaryStringIO.new
			
			@length = nil
			@processed = 0
		end
		
		# Receive the data via a TCP connection, process messages when we receive the indicated amount of data.
		def receive_data(data)
			# We buffer data until we've received the entire packet:
			@buffer.write(data)
			
			# Message includes a 16-bit length field.. we need to see if we have received it yet:
			if @length == nil
				if (@buffer.size - @processed) < 2
					raise LengthError.new("Malformed message smaller than two bytes received")
				end
				
				# Grab the length field:
				@length = @buffer.string.byteslice(@processed, 2).unpack('n')[0]
				@processed += 2
			end
			
			if (@buffer.size - @processed) >= @length
				data = @buffer.string.byteslice(@processed, @length)
				
				options = {:peer => RubyDNS::get_peer_details(self)}
				
				UDPHandler.process(@server, data, options) do |answer|
					data = answer.encode
					
					@server.logger.debug "Writing response to client (#{data.bytesize} bytes) via TCP..."
					
					self.send_data([data.bytesize].pack('n'))
					self.send_data(data)
				end
				
				@processed += @length
				@length = nil
			end
		end
		
		# Check that all data received was processed.
		def unbind
			if @processed != @buffer.size
				raise LengthError.new("Unprocessed data remaining (#{@buffer.size - @processed} bytes unprocessed)")
			end
		end
	end
	
end