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
require 'rubydns'
require 'rubydns/system'

# You can specify other DNS servers easily
# $R = Resolv::DNS.new(:nameserver => ["xx.xx.1.1", "xx.xx.2.2"])

R = RubyDNS::Resolver.new(RubyDNS::System::nameservers)
Name = Resolv::DNS::Name
IN = Resolv::DNS::Resource::IN

RubyDNS::run_server do
	# % dig +nocmd +noall +answer @localhost ANY dev.mydomain.org
	# dev.mydomain.org.	16000	IN	A	10.0.0.80
	# dev.mydomain.org.	16000	IN	MX	10 mail.mydomain.org.
	match(/dev.mydomain.org/, IN::ANY) do |transaction|
		transaction.append_question!
		
		[IN::A, IN::CNAME, IN::MX].each do |resource_class|
			logger.debug "Appending query for #{resource_class}..."
			transaction.append_query!(transaction.name, resource_class)
		end
	end
	
	# For this exact address record, return an IP address
	match("dev.mydomain.org", IN::A) do |transaction|
		transaction.respond!("10.0.0.80")
	end

	match("80.0.0.10.in-addr.arpa", IN::PTR) do |transaction|
		transaction.respond!(Name.create("dev.mydomain.org."))
	end

	match("dev.mydomain.org", IN::MX) do |transaction|
		transaction.respond!(10, Name.create("mail.mydomain.org."))
	end
	
	match(/^test([0-9]+).mydomain.org$/, IN::A) do |transaction, match_data|
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
		transaction.passthrough!(R)
	end
end
