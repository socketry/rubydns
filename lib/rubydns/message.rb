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
require 'resolv'

require 'base64'

require_relative 'logger'
require_relative 'extensions/resolv'

module RubyDNS
	UDP_TRUNCATION_SIZE = 512
	
	# The DNS message container.
	Message = Resolv::DNS::Message

	DecodeError = Resolv::DNS::DecodeError

	@@dump_bad_message = nil
	
	# Call this function with a path where bad messages will be saved. Any message that causes an exception to be thrown while decoding the binary will be saved in base64 for later inspection. The log file could grow quickly so be careful - not designed for long term use.
	def self.log_bad_messages!(log_path)
		bad_messages_log = Logger.new(log_path, 10, 1024*100)
		bad_messages_log.level = Logger::DEBUG
		
		@dump_bad_message = lambda do |error, data|
			bad_messages_log.debug("Bad message: #{Base64.encode64(data)}")
			RubyDNS.log_exception(bad_messages_log, error)
		end
	end
	
	# Decodes binary data into a {Message}.
	def self.decode_message(data)
		# Otherwise the decode process might fail with non-binary data.
		if data.respond_to? :force_encoding
			data.force_encoding("BINARY")
		end
		
		begin
			return Message.decode(data)
		rescue DecodeError
			raise
		rescue StandardError => error
			new_error = DecodeError.new(error.message)
			new_error.set_backtrace(error.backtrace)
			
			raise new_error
		end
		
	rescue => error
		# Log the bad messsage if required:
		if @dump_bad_message
			@dump_bad_message.call(error, data)
		end
		
		raise
	end
end
