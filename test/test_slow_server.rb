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

require 'helper'
require 'pathname'

require 'rubydns'
require 'rubydns/resolver'
require 'rubydns/extensions/string'

class SlowServer < RExec::Daemon::Base
	SERVER_PORTS = [[:udp, '127.0.0.1', 5330], [:tcp, '127.0.0.1', 5330]]
	
	@@base_directory = File.dirname(__FILE__)

	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	def self.run
		RubyDNS::run_server(:listen => SERVER_PORTS) do
			match(/\.*.com/, IN::A) do |transaction|
				defer do |fiber|
					# No domain exists, after 2 seconds:
					EventMachine::Timer.new(2) do
						transaction.fail!(:NXDomain)
					
						fiber.resume
					end
				end
			end
		
			otherwise do |transaction|
				transaction.fail!(:NXDomain)
			end
		end
	end
end

class SlowServerTest < Test::Unit::TestCase
	def setup
		SlowServer.start
	end
	
	def teardown
		SlowServer.stop
	end
	
	def test_timeout
		start_time = Time.now
		end_time = nil
		got_response = false
		
		# Because there are two servers, the total timeout is actually, 2 seconds
		resolver = RubyDNS::Resolver.new(SlowServer::SERVER_PORTS, :timeout => 1)
		
		EventMachine::run do
			resolver.query("apple.com", IN::A) do |response|
				end_time = Time.now
				
				got_response = response
				
				EventMachine::stop
			end
		end
		
		assert (end_time - start_time) <= 2.5, "Response should fail within timeout period."
		assert_equal RubyDNS::ResolutionFailure, got_response.class, "Response should be resolution failure."
	end
	
	def test_slow_request
		start_time = Time.now
		end_time = nil
		
		resolver = RubyDNS::Resolver.new(SlowServer::SERVER_PORTS, :timeout => 10)
		
		EventMachine::run do
			resolver.query("apple.com", IN::A) do |response|
				end_time = Time.now
				
				EventMachine::stop
			end
		end
		
		assert (end_time - start_time) > 2.0
	end
	
	def test_normal_request
		start_time = Time.now
		end_time = nil
		
		resolver = RubyDNS::Resolver.new(SlowServer::SERVER_PORTS, :timeout => 10)
		
		EventMachine::run do
			resolver.query("oriontransfer.org", IN::A) do |response|
				end_time = Time.now
				
				EventMachine::stop
			end
		end
		
		assert (end_time - start_time) < 2.0
	end
end
