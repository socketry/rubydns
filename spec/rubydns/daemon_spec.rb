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
require 'process/daemon'

class BasicTestServer < Process::Daemon
	SERVER_PORTS = [[:udp, '127.0.0.1', 5350], [:tcp, '127.0.0.1', 5350]]

	IN = Resolv::DNS::Resource::IN

	def working_directory
		File.expand_path("../tmp", __FILE__)
	end

	def startup
		Celluloid.boot
		
		# Start the RubyDNS server
		RubyDNS::run_server(:listen => SERVER_PORTS) do
			match("test.local", IN::A) do |transaction|
				transaction.respond!("192.168.1.1")
			end

			match(/foo.*/, IN::A) do |transaction|
				transaction.respond!("192.168.1.2")
			end

			match(/peername/, IN::A) do |transaction|
				transaction.respond!(transaction[:peer])
			end

			# Default DNS handler
			otherwise do |transaction|
				transaction.fail!(:NXDomain)
			end
		end
	end
end

describe "RubyDNS Daemonized Server" do
	before(:all) do
		Celluloid.shutdown
		
		# Trying to fork with Celluloid running is a recipe for disaster.
		# BasicTestServer.controller output: $stderr
		BasicTestServer.start
		
		Celluloid.boot
	end
	
	after(:all) do
		BasicTestServer.stop
	end
	
	it "should resolve local domain correctly" do
		expect(BasicTestServer.status).to be == :running
		
		resolver = RubyDNS::Resolver.new(BasicTestServer::SERVER_PORTS, search_domain: '')
	
		response = resolver.query("test.local")
		
		answer = response.answer.first
		
		expect(answer[0].to_s).to be == "test.local."
		expect(answer[2].address.to_s).to be == "192.168.1.1"
	end
	
	it "should pattern match correctly" do
		expect(BasicTestServer.status).to be == :running
		
		resolver = RubyDNS::Resolver.new(BasicTestServer::SERVER_PORTS)

		response = resolver.query("foobar")
		answer = response.answer.first
		
		expect(answer[0]).to be == resolver.fully_qualified_name("foobar")
		expect(answer[2].address.to_s).to be == "192.168.1.2"
	end
	
	it "should give peer ip address" do
		expect(BasicTestServer.status).to be == :running
		
		resolver = RubyDNS::Resolver.new(BasicTestServer::SERVER_PORTS)

		response = resolver.query("peername")
		answer = response.answer.first
		
		expect(answer[2].address.to_s).to be == "127.0.0.1"
	end
end
