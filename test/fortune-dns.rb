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

require 'digest/md5'

# You might need to change the user name "daemon". This can be a user name or a user id.
RUN_AS = "daemon"

if RExec.current_user != "root"
	$stderr.puts "Sorry, this command needs to be run as root!"
	exit 1
end

# The Daemon itself
class FortuneDNS < RExec::Daemon::Base
	@@var_directory = File.dirname(__FILE__)

	def self.run
		# Don't buffer output (for debug purposes)
		$stderr.sync = true
		
		cache = {}
		stats = {:requested => 0}
		
		# Start the RubyDNS server
		RubyDNS::run_server do
			on(:start) do
				RExec.change_user(RUN_AS)
			end

			match(/(.*)\.fortune/, :TXT) do |match, transaction|
				fortune = cache[match[1]]
				stats[:requested] += 1
				
				if fortune
					transaction.respond!(fortune)
				else
					transaction.failure(:NXDomain)
				end
			end
			
			match(/stats.fortune/, :TXT) do |match, transaction|
				transaction.respond!(stats.inspect)
			end
			
			match(/fortune/, [:CNAME]) do |match, transaction|
				fortune = `fortune -s`.gsub(/\s+/, " ").strip
				checksum = Digest::MD5.hexdigest(fortune)
				cache[checksum] = fortune
				
				name = Resolv::DNS::Name.create(checksum + ".fortune")
				
				transaction.respond!(name, :resource_class => :CNAME, :ttl => 0)
			end
			
			# Default DNS handler
			otherwise do |transaction|
				transaction.failure!(:NXDomain)
			end
		end
	end
end

# RExec daemon runner
FortuneDNS.daemonize
