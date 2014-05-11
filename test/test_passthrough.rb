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

require 'process/daemon'

class PassthroughServer < Process::Daemon
	SERVER_PORTS = [[:udp, '127.0.0.1', 5340], [:tcp, '127.0.0.1', 5340]]
	
	def working_directory
		File.join(__dir__, "tmp")
	end
	
	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN
	
	def startup
		resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
		
		# Start the RubyDNS server
		RubyDNS::run_server(:listen => SERVER_PORTS) do
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
end

class PassthroughTest < MiniTest::Test
	def setup
		PassthroughServer.start
	end
	
	def teardown
		PassthroughServer.stop
	end
	
	def test_basic_dns
		answer = nil, response = nil
		
		assert_equal :running, PassthroughServer.status
		
		EventMachine.run do
			resolver = RubyDNS::Resolver.new(
				PassthroughServer::SERVER_PORTS, 
				# Enable this to get more debug output from the resolver:
				# :logger => Logger.new($stderr)
			)
			
			resolver.query("google.com") do |response|
				refute_kind_of RubyDNS::ResolutionFailure, response
				
				assert_equal 1, response.ra
				
				answer = response.answer.first
				
				EventMachine.stop
			end
		end
		
		# Check whether we got some useful records in the answer:
		refute_nil answer
		assert answer.count > 0
		assert answer.any? {|record| record.kind_of? Resolv::DNS::Resource::IN::A}
	end
	
	def test_basic_dns_prefix
		answer = nil
		
		assert_equal :running, PassthroughServer.status
		
		EventMachine.run do
			resolver = RubyDNS::Resolver.new(PassthroughServer::SERVER_PORTS)
		
			resolver.query("a-slashdot.org") do |response|
				refute_kind_of RubyDNS::ResolutionFailure, response
				
				answer = response.answer.first
				
				EventMachine.stop
			end
		end
		
		assert answer != nil
		assert answer.count > 0
	end
end
