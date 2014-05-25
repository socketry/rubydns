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

require 'rubydns'
require 'benchmark'

require 'stackprof'

Name = Resolv::DNS::Name
IN = Resolv::DNS::Resource::IN

# Generate a million A record "domains":

million = {}

Benchmark.bm do |x|
	x.report("Generate names") do
		(1..1_000_000).each do |i|
			domain = "domain#{i}.local"
	
			million[domain] = "#{69}.#{(i >> 16)%256}.#{(i >> 8)%256}.#{i%256}"
		end
	end
end

# Run the server:

StackProf.run(mode: :cpu, out: 'rubydns.stackprof') do
	RubyDNS::run_server(:listen => [[:udp, '0.0.0.0', 5300]]) do
		@logger.level = Logger::WARN
	
		match(//, IN::A) do |transaction|
			transaction.respond!(million[transaction.name])
		end
		
		# Default DNS handler
		otherwise do |transaction|
			logger.info "Passing DNS request upstream..."
			transaction.fail!(:NXDomain)
		end
	end
end

# Expected output:
#
# > dig @localhost -p 5300 domain1000000
# 
# ; <<>> DiG 9.8.3-P1 <<>> @localhost -p 5300 domain1000000
# ; (3 servers found)
# ;; global options: +cmd
# ;; Got answer:
# ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 50336
# ;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0
# ;; WARNING: recursion requested but not available
# 
# ;; QUESTION SECTION:
# ;domain1000000.			IN	A
# 
# ;; ANSWER SECTION:
# domain1000000.		86400	IN	A	69.15.66.64
# 
# ;; Query time: 1 msec
# ;; SERVER: 127.0.0.1#5300(127.0.0.1)
# ;; WHEN: Fri May 16 19:17:48 2014
# ;; MSG SIZE  rcvd: 47
# 
