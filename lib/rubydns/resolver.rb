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

require 'rubydns/message'

module RubyDNS
	class InvalidProtocolError < StandardError
	end

	class ResolutionFailure < StandardError
	end

	class Resolver
		# Servers are specified in the same manor as options[:listen], e.g.
		#   [:tcp/:udp, address, port]
		# The sequence number can be capped with options[:sequence_max]
		# In the case of multiple servers, they will be checked in sequence.
		def initialize(servers, options = {})
			@servers = servers
			@sequence = 0

			@options = options
		end

		# Provides the next sequence identification number which is used to keep track of DNS messages.
		def next_id!
			return (@options[:sequence_max] && @sequence >= @options[:sequence_max]) ? (@sequence = 0) : (@sequence += 1)
		end

		# Look up a named resource of the given resource_class.
		def query(name, resource_class = Resolv::DNS::Resource::IN::A, &block)
			message = Resolv::DNS::Message.new(next_id!)
			message.rd = 1
			message.add_question name, resource_class

			send_message(message, &block)
		end

		def send_message(message, &block)
			Request.fetch(message, @servers, @options, &block)
		end

		# Yields a list of `Resolv::IPv4` and `Resolv::IPv6` addresses for the given `name` and `resource_class`.
		def addresses_for(name, resource_class = Resolv::DNS::Resource::IN::A, &block)
			query(name, resource_class) do |response|
				# Resolv::DNS::Name doesn't retain the trailing dot.
				name = name.sub(/\.$/, '')

				case response
				when Message
					yield response.answer.select{|record| record[0].to_s == name}.collect{|record| record[2].address}
				else
					yield []
				end
			end
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

				@logger = options[:logger]
			end

			attr :message
			attr :packet
			attr :logger

			def run!
				try_next_server!
			end

			def process_response!(response)
				if Exception === response
					@logger.warn "[#{@message.id}] Failure while processing response #{exception}!" if @logger
					RubyDNS.log_exception(@logger, response) if @logger

					try_next_server!
				elsif response.tc != 0
					@logger.warn "[#{@message.id}] Received truncated response!" if @logger

					try_next_server!
				elsif response.id != @message.id
					@logger.warn "[#{@message.id}] Received response with incorrect message id: #{response.id}" if @logger

					try_next_server!
				else
					@logger.debug "[#{@message.id}] Received valid response #{response.inspect}" if @logger

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

					@logger.debug "[#{@message.id}] Sending request to server #{@server.inspect}" if @logger

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
					timeout(@timeout) do
						@logger.debug "[#{@message.id}] Request timed out!" if @logger

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
					message = RubyDNS::decode_message(data)

					# Close connection from the remote server or we will run out of sockets
					close_connection

					# The message id must match, and it can't be truncated:
					@request.process_response!(message)
				rescue Resolv::DNS::DecodeError => error
					@request.process_response!(error)
				end
			end

			module TCPRequestHandler
				def self.open(host, port, request)
					EventMachine::connect(host, port, TCPRequestHandler, request)
				end

				def initialize(request)
					@request = request
					@buffer = nil
					@length = nil
				end

				def post_init
					data = @request.packet

					send_data([data.bytesize].pack('n'))
					send_data data
				end

				def receive_data(data)
					# We buffer data until we've received the entire packet:
					@buffer ||= BinaryStringIO.new
					@buffer.write(data)

					# If we've received enough data and we haven't figured out the length yet...
					if @length == nil and @buffer.size > 2
						# Extract the length from the buffer:
						@length = @buffer.string.byteslice(0, 2).unpack('n')[0]
					end

					# If we know what the length is, and we've got that much data, we can decode the message:
					if @length != nil and @buffer.size >= (@length + 2)
						data = @buffer.string.byteslice(2, @length)

						message = RubyDNS::decode_message(data)

						@request.process_response!(message)
					end

					# If we have received more data than expected, should this be an error?
				rescue Resolv::DNS::DecodeError => error
					@request.process_response!(error)
				end
			end
		end
	end
end