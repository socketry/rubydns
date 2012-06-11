# Copyright (c) 2009, 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
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

require 'rubydns/version'

if RUBY_VERSION < "1.9"
	require 'rubydns/extensions/resolv-1.8'
	require 'rubydns/extensions/string-1.8'
else
	require 'rubydns/extensions/resolv-1.9'
	require 'rubydns/extensions/string-1.9'
end

require 'rubydns/server'

require 'logger'

require 'rexec'
require 'rexec/daemon'

require 'rubydns/handler'

module RubyDNS
	
	# Run a server with the given rules. A number of options can be supplied:
	#
	# <tt>:interfaces</tt>:: A set of sockets or addresses as defined below.
	#
	# One important feature of DNS is the port it runs on. The <tt>options[:listen]</tt>
	# allows you to specify a set of network interfaces and ports to run the server on. This
	# must be a list of <tt>[protocol, interface address, port]</tt>.
	# 
	#   INTERFACES = [[:udp, "0.0.0.0", 5300]]
	#   RubyDNS::run_server(:listen => INTERFACES) do
	#     ...
	#   end
	#
	# You can specify already connected sockets if need be:
	#
	#   socket = UDPSocket.new; socket.bind("0.0.0.0", 53)
	#   Process::Sys.setuid(server_uid)
	#   INTERFACES = [socket]
	#
	# The default interface is <tt>[[:udp, "0.0.0.0", 53]]</tt>. The server typically needs
	# to run as root for this to work, since port 53 is privileged.
	#
	def self.run_server (options = {}, &block)
		server = RubyDNS::Server.new(&block)
		server.logger.info "Starting server..."
		
		options[:listen] ||= [[:udp, "0.0.0.0", 53], [:tcp, "0.0.0.0", 53]]
		
		EventMachine.run do
			server.fire(:setup)
			
			# Setup server sockets
			options[:listen].each do |spec|
				server.logger.info "Listening on #{spec.join(':')}"
				if spec[0] == :udp
					EventMachine.open_datagram_socket(spec[1], spec[2], UDPHandler, server)
				elsif spec[0] == :tcp
					EventMachine.start_server(spec[1], spec[2], TCPHandler, server)
				end
			end
			
			server.fire(:start)
		end
		
		server.fire(:stop)
	end
end

