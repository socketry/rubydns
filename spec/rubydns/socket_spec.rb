#!/usr/bin/env ruby

# Copyright, 2014, by Samuel G. D. Williams. <http://www.codeotaku.com>
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
require 'rubydns/system'

module RubyDNS::SocketSpec
	IN = Resolv::DNS::Resource::IN
	
	describe RubyDNS::TCPSocketHandler do
		before(:all) do
			Celluloid.shutdown
			Celluloid.boot
		end
	
		it "should create server with existing TCP socket" do
			socket = TCPServer.new('127.0.0.1', 2002)
			
			# Start the RubyDNS server
			@server = RubyDNS::run_server(:listen => [socket], asynchronous: true) do
				resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
				
				match(/.*\.com/, IN::A) do |transaction|
					transaction.passthrough!(resolver)
				end
			end
			
			resolver = RubyDNS::Resolver.new([[:tcp, '127.0.0.1', 2002]])
			response = resolver.query('google.com')
			expect(response.class).to be == RubyDNS::Message
		end
	end
	
	describe RubyDNS::UDPSocketHandler do
		before(:all) do
			Celluloid.shutdown
			Celluloid.boot
		end
		
		it "should create server with existing UDP socket" do
			socket = UDPSocket.new
			socket.bind('127.0.0.1', 2002)
			
			# Start the RubyDNS server
			@server = RubyDNS::run_server(:listen => [socket], asynchronous: true) do
				resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
			
				match(/.*\.com/, IN::A) do |transaction|
					transaction.passthrough!(resolver)
				end
			end
			
			resolver = RubyDNS::Resolver.new([[:udp, '127.0.0.1', 2002]])
			response = resolver.query('google.com')
			expect(response.class).to be == RubyDNS::Message
		end
	end
end
