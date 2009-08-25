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

# You can specify other DNS servers easily
# $R = Resolv::DNS.new(:nameserver => ["xx.xx.1.1", "xx.xx.2.2"])

$R = Resolv::DNS.new
Name = Resolv::DNS::Name

RubyDNS::run_server do
	# For this exact address record, return an IP address
	match("dev.mydomain.org", :A) do |transaction|
		transaction.respond!("10.0.0.80")
	end

	match("80.0.0.10.in-addr.arpa", :PTR) do |transaction|
		transaction.respond!(Name.create("dev.mydomain.org."))
	end

	match("dev.mydomain.org", :MX) do |transaction|
		transaction.respond!(10, Name.create("mail.mydomain.org."))
	end
	
	match(/^test([0-9]+).mydomain.org$/, :A) do |match_data, transaction|
		offset = match_data[1].to_i
		
		if offset > 0 && offset < 10
			logger.info "Responding with address #{"10.0.0." + (90 + offset).to_s}..."
			transaction.respond!("10.0.0." + (90 + offset).to_s)
		else
			logger.info "Address out of range: #{offset}!"
			false
		end
	end

	# Default DNS handler
	otherwise do |transaction|
		logger.info "Passing DNS request upstream..."
		transaction.passthrough!($R)
	end
end
