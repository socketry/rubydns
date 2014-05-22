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

class SlowServerTest < MiniTest::Test
	SERVER_PORTS = [[:udp, '127.0.0.1', 5330], [:tcp, '127.0.0.1', 5330]]
	IN = Resolv::DNS::Resource::IN
	
	def setup
		Celluloid.boot
		
		RubyDNS::run_server(:listen => SERVER_PORTS, asynchronous: true) do
			match(/\.*.com/, IN::A) do |transaction|
				@logger.info "Sleeping for 2 seconds..."
				
				#sleep 2
				
				@logger.info "Failing after 2 seconds:"
				
				transaction.fail!(:NXDomain)
			end
		
			otherwise do |transaction|
				transaction.fail!(:NXDomain)
			end
		end
		
		sleep 1
	end
	
	def teardown
		Celluloid.shutdown
	end
	
	def _test_timeout
		# Because there are two servers, the total timeout is actually, 2 seconds
		resolver = RubyDNS::Resolver.new(SERVER_PORTS, :timeout => 1)
		
		start_time = Time.now
		
		assert_raises RubyDNS::ResolutionFailure do
			response = resolver.query("apple.com", IN::A)
		end
		
		end_time = Time.now
		
		assert_operator end_time - start_time, :<=, 2.5, "Response should fail within timeout period."
	end
	
	def test_slow_request
		start_time = Time.now
		
		resolver = RubyDNS::Resolver.new(SERVER_PORTS, :timeout => 10)
		
		assert_raises RubyDNS::ResolutionFailure do
			response = resolver.query("apple.com", IN::A)
		end
		
		end_time = Time.now
		
		assert_operator end_time - start_time, :>, 2.0, "Response should fail within timeout period."
	end
	
	def _test_normal_request
		start_time = Time.now
		end_time = nil
		
		resolver = RubyDNS::Resolver.new(SERVER_PORTS, :timeout => 10)
		
		assert_raises RubyDNS::ResolutionFailure do
			resolver.query("oriontransfer.org", IN::A)
		end
		
		assert_operator end_time - start_time, :<, 2.0, "Response should fail immediately"
	end
end
