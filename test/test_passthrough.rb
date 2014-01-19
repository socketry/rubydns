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

require 'rexec'
require 'rexec/daemon'

class TestPassthroughServer < RExec::Daemon::Base
	SERVER_PORTS = [[:udp, '127.0.0.1', 5340], [:tcp, '127.0.0.1', 5340]]
	
	@@base_directory = File.dirname(__FILE__)

	def self.run
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

class PassthroughTest < Test::Unit::TestCase
	# LOG_PATH = File.join(__dir__, "log/TestPassthroughServer.log")
	
	def setup
		# system("rm", LOG_PATH)
		TestPassthroughServer.start
	end
	
	def teardown
		TestPassthroughServer.stop
		# system("cat", LOG_PATH)
	end
	
	def test_basic_dns
		answer = nil
		
		assert_equal :running, RExec::Daemon::ProcessFile.status(TestPassthroughServer)
		
		EventMachine.run do
			resolver = RubyDNS::Resolver.new(TestPassthroughServer::SERVER_PORTS)
		
			resolver.query("google.com") do |response|
				answer = response.answer.first
				
				EventMachine.stop
			end
		end
		
		assert answer != nil
		assert answer.count > 0
	end
	
	def test_basic_dns_prefix
		answer = nil
		
		assert_equal :running, RExec::Daemon::ProcessFile.status(TestPassthroughServer)
		
		EventMachine.run do
			resolver = RubyDNS::Resolver.new(TestPassthroughServer::SERVER_PORTS)
		
			resolver.query("a-slashdot.org") do |response|
				answer = response.answer.first
				
				EventMachine.stop
			end
		end
		
		assert answer != nil
		assert answer.count > 0
	end
end
