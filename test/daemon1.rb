#!/usr/bin/env ruby

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

require 'rubygems'

require 'rexec'
require 'rexec/daemon'

require 'rubygems'
require 'rubydns'

INTERFACES = [
	[:udp, "0.0.0.0", 5300]
]

# Very simple XMLRPC daemon
class TestDaemon < RExec::Daemon::Base
  @@var_directory = "/tmp/ruby-test/var"
  
  def self.run
		$stderr.sync = true

		$R = Resolv::DNS.new

		RubyDNS::run_server(:listen => INTERFACES) do
			# Fail the resolution of certain domains ;)
			match(/(m?i?c?r?o?s?o?f?t)/) do |match_data, transaction|
				if match_data[1].size > 7
					logger.info "Dropping domain MICROSOFT..."
					transaction.failure!(:NXDomain)
				else
					# Pass the request to the otherwise handler
					false
				end
			end
			
			# Hmm....
			match(/^(.+\.)?sco\./) do |match_data, transaction|
				logger.info "Dropping domain SCO..."
				transaction.failure!(:NXDomain)
			end

			# Default DNS handler
			otherwise do |transaction|
				logger.info "Passing DNS request upstream..."
				transaction.passthrough!($R)
			end
		end
  end
end

TestDaemon.daemonize
