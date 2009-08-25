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
