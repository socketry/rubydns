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

require 'minitest/autorun'

require 'rubydns'
require 'rubydns/extensions/string'

require 'process/daemon'

class TruncatedServer < Process::Daemon
	SERVER_PORTS = [[:udp, '127.0.0.1', 5320], [:tcp, '127.0.0.1', 5320]]
	
	def working_directory
		File.expand_path("../tmp", __FILE__)
	end
	
	IN = Resolv::DNS::Resource::IN
	
	def startup
		# RubyDNS::log_bad_messages!("bad.log")
		
		# Start the RubyDNS server
		RubyDNS::run_server(:listen => SERVER_PORTS) do
			match("truncation", IN::TXT) do |transaction|
				text = "Hello World! " * 100
				transaction.respond!(*text.chunked)
			end
			
			# Default DNS handler
			otherwise do |transaction|
				transaction.fail!(:NXDomain)
			end
		end
	end
end

class TruncationTest < MiniTest::Test
	def setup
		TruncatedServer.controller output: File.open("/dev/null", "w")
		
		TruncatedServer.start
	end
	
	def teardown
		TruncatedServer.stop
	end
	
	IN = Resolv::DNS::Resource::IN
	
	def test_tcp_failover
		resolver = RubyDNS::Resolver.new(TruncatedServer::SERVER_PORTS)
		
		EventMachine::run do
			resolver.query("truncation", IN::TXT) do |response|
				refute_kind_of RubyDNS::ResolutionFailure, response
				
				text = response.answer.first
				
				assert_equal "Hello World! " * 100, text[2].strings.join
				
				EventMachine::stop
			end
		end
	end
end
