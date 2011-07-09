#!/usr/bin/env ruby

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

require 'rubygems'

require 'rexec'
require 'rexec/daemon'

require 'rubygems'
require 'rubydns'

# To run this command, use the standard daemon syntax as root
# ./daemon2.rb start

# You should be able to see that the server has dropped priviledges
#   # ps aux | grep daemon2.rb
#   daemon   16555   0.4  0.0    81392   2024   ??  S     3:35am   0:00.28 ruby ../test/daemon2.rb start

# Test using the following command
# dig @localhost test.mydomain.org
# dig +tcp @localhost test.mydomain.org

# You might need to change the user name "daemon". This can be a user name or a user id.
RUN_AS = "daemon"

INTERFACES = [
	[:udp, "0.0.0.0", 53],
	[:tcp, "0.0.0.0", 53]
]

# We need to be root in order to bind to privileged port
if RExec.current_user != "root"
	$stderr.puts "Sorry, this command needs to be run as root!"
	exit 1
end

# The Daemon itself
class Server < RExec::Daemon::Base
	@@var_directory = File.dirname(__FILE__)

	def self.run
		# Don't buffer output (for debug purposes)
		$stderr.sync = true

		# Use upstream DNS for name resolution (These ones are Orcon DNS in NZ)
		$R = Resolv::DNS.new(:nameserver => ["8.8.8.8"])

		# Start the RubyDNS server
		RubyDNS::run_server(:listen => INTERFACES) do
			on(:start) do
				RExec.change_user(RUN_AS)
			end

			match("test.mydomain.org", :A) do |transaction|
				transaction.respond!("10.0.0.80")
			end

			# Default DNS handler
			otherwise do |transaction|
				logger.info "Passthrough: #{transaction}"
				transaction.passthrough!($R)
			end
		end
	end
end

# RExec daemon runner
Server.daemonize
