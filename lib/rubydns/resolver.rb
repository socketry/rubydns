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

require_relative 'handler'

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
		# Wait for up to 2 seconds for a response. Override with `options[:timeout]`
		DEFAULT_TIMEOUT = 5.0
		
		# 10ms wait between making requests. Override with `options[:delay]`
		DEFAULT_DELAY = 0.01
		
		# Try a given request 5 times before failing. Override with `options[:retries]`.
		DEFAULT_RETRIES = 10
		
		include Celluloid::IO
		
		# Servers are specified in the same manor as options[:listen], e.g.
		#   [:tcp/:udp, address, port]
		# In the case of multiple servers, they will be checked in sequence.
		def initialize(servers, options = {})
			@servers = servers
			
			@options = options
			
			@origin = options[:origin] || nil
			
			@logger = options[:logger] || Celluloid.logger
		end
		
		attr_accessor :origin
		
		def fully_qualified_name(name)
			# If we are passed an existing deconstructed name:
			if Resolv::DNS::Name === name
				if name.absolute?
					return name
				else
					return name.with_origin(@origin)
				end
			end
			
			# ..else if we have a string, we need to do some basic processing:
			if name.end_with? '.'
				return Resolv::DNS::Name.create(name)
			else
				return Resolv::DNS::Name.create(name).with_origin(@origin)
			end
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
			message.add_question fully_qualified_name(name), resource_class
			
			dispatch_request(message)
		end
		
		# Yields a list of `Resolv::IPv4` and `Resolv::IPv6` addresses for the given `name` and `resource_class`. Raises a ResolutionFailure if no severs respond.
		def addresses_for(name, resource_class = Resolv::DNS::Resource::IN::A, options = {})
			name = fully_qualified_name(name)
			
			cache = options.fetch(:cache, {})
			retries = options.fetch(:retries, DEFAULT_RETRIES)
			delay = options.fetch(:delay, DEFAULT_DELAY)
			
			records = lookup(name, resource_class, cache) do |name, resource_class|
				response = nil
				
				retries.times do |i|
					# Wait 10ms before trying again:
					sleep delay if delay and i > 0
					
					response = query(name, resource_class)
					
					break if response
				end
				
				response or abort ResolutionFailure.new("Could not resolve #{name} after #{retries} attempt(s).")
			end
			
			addresses = []
			
			if records
				records.each do |record|
					if record.respond_to? :address
						addresses << record.address
					else
						# The most common case here is that record.class is IN::CNAME and we need to figure out the address. Usually the upstream DNS server would have replied with this too, and this will be loaded from the response if possible without requesting additional information.
						addresses += addresses_for(record.name, record.class, options.merge(cache: cache))
					end
				end
			end
			
			if addresses.size > 0
				return addresses
			else
				abort ResolutionFailure.new("Could not find any addresses for #{name}.")
			end
		end
		
		def request_timeout
			@options[:timeout] || DEFAULT_TIMEOUT
		end
		
		# Send the message to available servers. If no servers respond correctly, nil is returned. This result indicates a failure of the resolver to correctly contact any server and get a valid response.
		def dispatch_request(message)
			request = Request.new(message, @servers)
			
			request.each do |server|
				@logger.debug "[#{message.id}] Sending request #{message.question.inspect} to server #{server.inspect}" if @logger
				
				begin
					response = nil
					
					# This may be causing a problem, perhaps try:
					# 	after(timeout) { socket.close }
					# https://github.com/celluloid/celluloid-io/issues/121
					timeout(request_timeout) do
						response = try_server(request, server)
					end
					
					if valid_response(message, response)
						return response
					end
				rescue Task::TimeoutError
					@logger.debug "[#{message.id}] Request timed out!" if @logger
				rescue InvalidResponseError
					@logger.warn "[#{message.id}] Invalid response from network: #{$!}!" if @logger
				rescue DecodeError
					@logger.warn "[#{message.id}] Error while decoding data from network: #{$!}!" if @logger
				rescue IOError
					@logger.warn "[#{message.id}] Error while reading from network: #{$!}!" if @logger
				end
			end
			
			return nil
		end
		
		private
		
		# Lookup a name/resource_class record but use the records cache if possible reather than making a new request if possible.
		def lookup(name, resource_class = Resolv::DNS::Resource::IN::A, records = {})
			records.fetch(name) do
				response = yield(name, resource_class)
				
				if response
					response.answer.each do |name, ttl, record|
						(records[name] ||= []) << record
					end
				end
				
				records[name]
			end
		end
		
		def try_server(request, server)
			case server[0]
			when :udp
				try_udp_server(request, server[1], server[2])
			when :tcp
				try_tcp_server(request, server[1], server[2])
			else
				raise InvalidProtocolError.new(server)
			end
		end
		
		def valid_response(message, response)
			if response.tc != 0
				@logger.warn "[#{message.id}] Received truncated response!" if @logger
			elsif response.id != message.id
				@logger.warn "[#{message.id}] Received response with incorrect message id: #{response.id}!" if @logger
			else
				@logger.debug "[#{message.id}] Received valid response with #{response.answer.count} answer(s)." if @logger
				
				return true
			end
			
			return false
		end
		
		def try_udp_server(request, host, port)
			family = RubyDNS::address_family(host)
			socket = UDPSocket.new(family)
			
			socket.send(request.packet, 0, host, port)
			
			data, (_, remote_port) = socket.recvfrom(UDP_TRUNCATION_SIZE, 0)
			# Need to check host, otherwise security issue.
			
			# May indicate some kind of spoofing attack:
			if port != remote_port
				raise InvalidResponseError.new("Data was not received from correct remote port (#{port} != #{remote_port})")
			end
			
			message = RubyDNS::decode_message(data)
		ensure
			socket.close if socket
		end
		
		def try_tcp_server(request, host, port)
			begin
				socket = TCPSocket.new(host, port)
			rescue Errno::EALREADY
				# This is a hack to work around faulty behaviour in celluloid-io:
				# https://github.com/celluloid/celluloid/issues/436
				raise IOError.new("Could not connect to remote host!")
			end
			
			StreamTransport.write_chunk(socket, request.packet)
			
			input_data = StreamTransport.read_chunk(socket)
			
			message = RubyDNS::decode_message(input_data)
		rescue Errno::ECONNREFUSED => error
			raise IOError.new(error.message)
		rescue Errno::EPIPE => error
			raise IOError.new(error.message)
		rescue Errno::ECONNRESET => error
			raise IOError.new(error.message)
		ensure
			socket.close if socket
		end
		
		# Manages a single DNS question message across one or more servers.
		class Request
			def initialize(message, servers)
				@message = message
				@packet = message.encode
				
				@servers = servers.dup
				
				# We select the protocol based on the size of the data:
				if @packet.bytesize > UDP_TRUNCATION_SIZE
					@servers.delete_if{|server| server[0] == :udp}
				end
			end
			
			attr :message
			attr :packet
			attr :logger
			
			def each(&block)
				@servers.each do |server|
					next if @packet.bytesize > UDP_TRUNCATION_SIZE
					
					yield server
				end
			end

			def update_id!(id)
				@message.id = id
				@packet = @message.encode
			end
		end
	end
end
