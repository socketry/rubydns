#!/usr/bin/env ruby

# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

module RubyDNS::PassthroughSpec
	SERVER_PORTS = [[:udp, '127.0.0.1', 5340], [:tcp, '127.0.0.1', 5340]]
	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN
	
	describe "RubyDNS Passthrough Server" do
		before(:all) do
			Celluloid.shutdown
			Celluloid.boot
		
			# Start the RubyDNS server
			@server = RubyDNS::run_server(:listen => SERVER_PORTS, asynchronous: true) do
				resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
			
				match(/.*\.com/, IN::A) do |transaction|
					transaction.passthrough!(resolver)
				end

				match(/a-(.*\.org)/) do |transaction, match_data|
					transaction.passthrough!(resolver, :name => match_data[1])
				end

				# Default DNS handler
				otherwise do |transaction|
					transaction.fail!(:NXDomain)
				end
			end
		end
	
		it "should resolve domain correctly" do
			resolver = RubyDNS::Resolver.new(SERVER_PORTS)
		
			response = resolver.query("google.com")
			expect(response.ra).to be == 1
		
			answer = response.answer.first
			expect(answer).not_to be == nil
			expect(answer.count).to be > 0
		
			addresses = answer.select {|record| record.kind_of? Resolv::DNS::Resource::IN::A}
			expect(addresses.size).to be > 0
		end
	
		it "should resolve prefixed domain correctly" do
			resolver = RubyDNS::Resolver.new(SERVER_PORTS)
		
			response = resolver.query("a-slashdot.org")
			answer = response.answer.first
		
			expect(answer).not_to be == nil
			expect(answer.count).to be > 0
		end
	end
end
