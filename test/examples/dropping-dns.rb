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

require 'rubygems'
require 'rubydns'

require 'rubydns/resolver'
require 'rubydns/system'

INTERFACES = [
	[:udp, "0.0.0.0", 5300]
]

class DroppingDaemon < RExec::Daemon::Base
	# You can specify a specific directory to use for run-time information (pid, logs, etc):
	# @@base_directory = File.expand_path("../", __FILE__)
	# @@base_directory = "/var"

	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN
	R = RubyDNS::Resolver.new(RubyDNS::System::nameservers)
	
	def self.run
		RubyDNS::run_server(:listen => INTERFACES) do
			# Fail the resolution of certain domains ;)
			match(/(m?i?c?r?o?s?o?f?t)/) do |transaction, match_data|
				if match_data[1].size > 7
					logger.info "Dropping domain MICROSOFT..."
					transaction.fail!(:NXDomain)
				else
					# Pass the request to the otherwise handler
					false
				end
			end
			
			# Hmm....
			match(/^(.+\.)?sco\./) do |transaction|
				logger.info "Dropping domain SCO..."
				transaction.fail!(:NXDomain)
			end

			# Default DNS handler
			otherwise do |transaction|
				logger.info "Passing DNS request upstream..."
				transaction.passthrough!(R)
			end
		end
  end
end

DroppingDaemon.daemonize
