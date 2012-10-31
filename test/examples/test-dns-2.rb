#!/usr/bin/env ruby

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

require 'rubygems'
require 'rexec'
require 'rexec/daemon'
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
	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	# Use upstream DNS for name resolution.
	UPSTREAM = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])

	def self.run
		# Don't buffer output (for debug purposes)
		$stderr.sync = true
		
		# Start the RubyDNS server
		RubyDNS::run_server(:listen => INTERFACES) do
			on(:start) do
				RExec.change_user(RUN_AS)
			end

			match("test.mydomain.org", IN::A) do |transaction|
				transaction.respond!("10.0.0.80")
			end

			# Default DNS handler
			otherwise do |transaction|
				logger.info "Passthrough: #{transaction}"
				transaction.passthrough!(UPSTREAM)
			end
		end
	end
end

# RExec daemon runner
Server.daemonize
