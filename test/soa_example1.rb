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
require 'rubydns'

$R = Resolv::DNS.new
Name = Resolv::DNS::Name

RubyDNS::run_server(:listen => [[:udp, "0.0.0.0", 5300]]) do
	# SOA Record
	#   dig @localhost -p 5300 SOA mydomain.org
	match("mydomain.org", :SOA) do |transaction|
		#
		# For more details about these headers please see:
		#   http://www.ripe.net/ripe/docs/ripe-203.html
		#
		
		transaction.respond!(
			Name.create("ns.mydomain.org."),    # Master Name
			Name.create("admin.mydomain.org."), # Responsible Name
			File.mtime(__FILE__).to_i,          # Serial Number
			1200,                               # Refresh Time
			900,                                # Retry Time
			3600000,                            # Maximum TTL / Expiry Time
			172800                              # Minimum TTL
		)
	end
	
	# Default NS record
	#   dig @localhost -p 5300 NS
	match("", :NS) do |transaction|
		transaction.respond!(Name.create("ns.mydomain.org."))
	end

	# For this exact address record, return an IP address
	#   dig @localhost -p 5300 CNAME bob.mydomain.org
	match(/([^.]+).mydomain.org/, :CNAME) do |match_data, transaction|
		transaction.respond!(Name.create("www.mydomain.org"))
		transaction.append_query!("www.mydomain.org", :A)
	end

	match("80.0.0.10.in-addr.arpa", :PTR) do |transaction|
		transaction.respond!(Name.create("www.mydomain.org."))
	end

	match("www.mydomain.org", :A) do |transaction|
		transaction.respond!("10.0.0.80")
	end
	
	match("ns.mydomain.org", :A) do |transaction|
		transaction.respond!("10.0.0.10")
	end
	
	# Default DNS handler
	otherwise do |transaction|
		# Non-Existant Domain
		transaction.failure!(:NXDomain)
	end
end
