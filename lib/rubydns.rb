# Copyright (c) 2009 Samuel Williams. Released under the GNU GPLv3.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Thanks to "jmorgan" who provided some basic ideas for how to do this
# using Ruby: http://half-penny.org/computing/simple-ruby-dns-server

require 'rubydns/version'
require 'rubydns/resolv'
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

