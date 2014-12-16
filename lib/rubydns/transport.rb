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

require 'stringio'
require 'ipaddr'

require_relative 'message'

module RubyDNS
	def self.address_family(host)
		return IPAddr.new(host).family
	end
	
	# A helper class for processing incoming network data.
	class BinaryStringIO < StringIO
		def initialize
			super
		
			set_encoding("BINARY")
		end
	end
	
	module StreamTransport
		def self.read_chunk(socket)
			# The data buffer:
			buffer = BinaryStringIO.new
			
			# First we need to read in the length of the packet
			while buffer.size < 2
				buffer.write socket.readpartial(1)
			end
			
			# Read in the length, the first two bytes:
			length = buffer.string.byteslice(0, 2).unpack('n')[0]
			
			# Read data until we have the amount specified:
			while (buffer.size - 2) < length
				required = (2 + length) - buffer.size
				
				# Read precisely the required amount:
				buffer.write socket.readpartial(required)
			end
			
			return buffer.string.byteslice(2, length)
		end
		
		def self.write_message(socket, message)
			write_chunk(socket, message.encode)
		end
		
		def self.write_chunk(socket, output_data)
			socket.write([output_data.bytesize].pack('n'))
			socket.write(output_data)
			
			return output_data.bytesize
		end
	end
end
