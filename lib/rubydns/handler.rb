
require 'eventmachine'
require 'stringio'

module RubyDNS
	
	UDP_TRUNCATION_SIZE = 512
	
	module UDPHandler
		def initialize(server)
			@server = server
		end
		
		def self.process(server, data, &block)
			server.logger.debug "Receiving incoming query..."
			
			begin
				server.receive_data(data) do |answer|
					yield answer.encode
				end
			rescue
				server.logger.error "Error processing request!"
				server.logger.error "#{$!.class}: #{$!.message}"

				$!.backtrace.each { |at| server.logger.error at }
			end
		end
		
		def receive_data(data)
			UDPHandler.process(@server, data) do |result|
				self.send_data(result)
			end
		end
	end
	
	class LengthError < StandardError
	end
	
	module TCPHandler
		def initialize(server)
			@server = server
			@buffer = nil
			@length = nil
			@processed = 0
		end
		
		def receive_data(data)
			@buffer ||= StringIO.new
			@buffer.write(data)
			
			# Message includes a 16-bit length field
			if @length == nil
				if (@buffer.size - @processed) < 2
					raise LengthError.new("Malformed message smaller than two bytes received")
				end
				
				@length = @buffer.string[@processed, 2].unpack('n')[0]
				@processed += 2
			end
			
			
			if (@buffer.size - @processed) >= @length
				data = @buffer.string[@processed, @length]
				
				UDPHandler.process(@server, data) do |result|
					self.send_data([result.size].pack('n'))
					self.send_data(result)
				end
				
				@processed += @length
				@length = nil
			end
		end
		
		def unbind
			if @processed != @buffer.size
				raise LengthError.new("Unprocessed data remaining (#{@buffer.size - @processed} bytes unprocessed)")
			end
		end
	end
	
end