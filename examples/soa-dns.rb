#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017, by Samuel Williams.

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

require "rubygems"
require "rubydns"

$R = Resolv::DNS.new
Name = Resolv::DNS::Name
IN = Resolv::DNS::Resource::IN

RubyDNS.run_server([[:udp, "0.0.0.0", 5400]]) do
	# SOA Record
	#   dig @localhost -p 5400 SOA mydomain.org
	match("mydomain.org", IN::SOA) do |transaction|
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
			3_600_000,                          # Maximum TTL / Expiry Time
			172_800                             # Minimum TTL
		)
		
		transaction.append!(transaction.question, IN::NS, section: :authority)
	end

	# Default NS record
	#   dig @localhost -p 5400 mydomain.org NS
	match("mydomain.org", IN::NS) do |transaction|
		transaction.respond!(Name.create("ns.mydomain.org."))
	end

	# For this exact address record, return an IP address
	#   dig @localhost -p 5400 CNAME bob.mydomain.org
	match(/([^.]+).mydomain.org/, IN::CNAME) do |transaction|
		transaction.respond!(Name.create("www.mydomain.org"))
		transaction.append!("www.mydomain.org", IN::A)
	end

	match("80.0.0.10.in-addr.arpa", IN::PTR) do |transaction|
		transaction.respond!(Name.create("www.mydomain.org."))
	end

	match("www.mydomain.org", IN::A) do |transaction|
		transaction.respond!("10.0.0.80")
	end

	match("ns.mydomain.org", IN::A) do |transaction|
		transaction.respond!("10.0.0.10")
	end

	# Default DNS handler
	otherwise do |transaction|
		# Non-Existant Domain
		transaction.fail!(:NXDomain)
	end
end
