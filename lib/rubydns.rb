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

require 'rubydnd/version'
require 'rubydns/resolv'
require 'rubydns/server'

require 'logger'

require 'rexec'
require 'rexec/daemon'

module RubyDNS
	
	# Run a server with the given rules. A number of options can be supplied:
	#
	# <tt>:interfaces</tt>:: A set of sockets or addresses as defined below.
	#
	# One important feature of DNS is the port it runs on. The <tt>options[:interfaces]</tt>
	# allows you to specify a set of network interfaces and ports to run the server on. This
	# must be a list of <tt>[protocol, interface address, port]</tt>.
	# 
	#   INTERFACES = [[:udp, "0.0.0.0", 5300]]
	#   RubyDNS::run_server(:interfaces => INTERFACES) do
	#     ...
	#   end
	#
	# You can specify already connected sockets if need be:
	#
	#   socket = UDPSocket.new; socket.bind("0.0.0.0", 53)
	#   Process::Sys.setuid(server_uid)
	#   INTERFACES = [socket]
	#
	# The default interface is <tt>[[:udp, "0.0.0.0", 53]]</tt>. The server needs to run
	# as root for this to work, and thus should not be used in production environment.
	#
	def self.run_server (options = {}, &block)
		server = RubyDNS::Server.new(&block)
		threads = ThreadGroup.new

		server.logger.info "Starting server..."

		options[:listen] ||= [[:udp, "0.0.0.0", 53]]

		sockets = []
		
		# Setup server sockets
		options[:listen].each do |spec|
			if spec.kind_of?(BasicSocket)
				sockets << spec
			elsif spec[0] == :udp
				socket = UDPSocket.new
				socket.bind(spec[1], spec[2])

				sockets << socket
			elsif spec[0] == :tcp
				server.logger.warn "Sorry, TCP is not currently supported!"
			end
		end
		
		begin
			# Listen for incoming packets
			while true
				ready = IO.select(sockets)

				ready[0].each do |socket|
					packet, sender = socket.recvfrom(1024*5)
					server.logger.debug "Receiving incoming query..."

					thr = Thread.new do
						begin
							result = server.receive_data(packet)

							server.logger.debug "Sending result to #{sender.inspect}:"
							server.logger.debug "#{result.inspect}"
							socket.send(result, 0, sender[2], sender[1])
						rescue
							server.logger.error "Error processing request!"
							server.logger.error "#{$!.class}: #{$!.message}"
							$!.backtrace.each { |at| server.logger.error at }
						end
					end
					
					threads.add thr
				end
			end
		rescue Interrupt
			server.logger.info "Server interrupted - stopping #{threads.list.size} request(s)."
			threads.list.each { |thr| thr.join }
		end
	end
end

