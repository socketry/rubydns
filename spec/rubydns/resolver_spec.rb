#!/usr/bin/env rspec

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

module RubyDNS::ResolverSpec
	describe RubyDNS::Resolver do
		class JunkUDPServer
			include Celluloid::IO
	
			def initialize
				@socket = UDPSocket.new
				@socket.bind("0.0.0.0", 6060)
		
				async.run
			end
	
			finalizer :shutdown
	
			def finalize
				@socket.close if @socket
			end
	
			def run
				data, (_, port, host) = @socket.recvfrom(1024, 0)
		
				@socket.send("Foobar", 0, host, port)
			end
		end

		class JunkTCPServer
			include Celluloid::IO
	
			def initialize
				@socket = TCPServer.new("0.0.0.0", 6060)
		
				async.run
			end
	
			finalizer :shutdown
	
			def finalize
				@socket.close if @socket
			end
	
			def run
				# @logger.debug "Waiting for incoming TCP connections #{@socket.inspect}..."
				loop { async.handle_connection @socket.accept }
			end
	
			def handle_connection(socket)
				socket.write("\0\0obar")
			ensure
				socket.close
			end
		end

		before(:all) do
			Celluloid.shutdown
			Celluloid.boot
	
			JunkUDPServer.supervise
			JunkTCPServer.supervise
		end

		it "should result in non-existent domain" do
			resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
	
			response = resolver.query('foobar.oriontransfer.org')
	
			expect(response.rcode).to be == Resolv::DNS::RCode::NXDomain
		end

		it "should result in some answers" do
			resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
	
			response = resolver.query('google.com')
	
			expect(response.class).to be == RubyDNS::Message
			expect(response.answer.size).to be > 0
		end

		it "should return no results" do
			resolver = RubyDNS::Resolver.new([])
	
			response = resolver.query('google.com')
	
			expect(response).to be == nil
		end

		it "should fail to get addresses" do
			resolver = RubyDNS::Resolver.new([])
	
			expect{resolver.addresses_for('google.com')}.to raise_error(RubyDNS::ResolutionFailure)
		end

		it "should fail with decode error from bad udp server" do
			resolver = RubyDNS::Resolver.new([[:udp, "0.0.0.0", 6060]])
			
			response = resolver.query('google.com')
			
			expect(response).to be == nil
		end

		it "should fail with decode error from bad tcp server" do
			resolver = RubyDNS::Resolver.new([[:tcp, "0.0.0.0", 6060]])
			
			response = resolver.query('google.com')
			
			expect(response).to be == nil
		end

		it "should return some IPv4 and IPv6 addresses" do
			resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
	
			addresses = resolver.addresses_for("www.google.com.")
	
			expect(addresses.size).to be > 0
	
			addresses.each do |address|
				expect(address).to be_kind_of(Resolv::IPv4) | be_kind_of(Resolv::IPv6)
			end
		end
		
		it "should recursively resolve CNAME records" do
			resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
			
			addresses = resolver.addresses_for('www.baidu.com')
			
			expect(addresses.size).to be > 0
		end
	end
end
