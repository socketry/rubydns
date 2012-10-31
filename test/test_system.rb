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
require 'rubydns/system'

require 'rexec'

class SystemTest < Test::Unit::TestCase
	def test_system_nameservers
		# There technically should be at least one nameserver:
		resolver = RubyDNS::Resolver.new(RubyDNS::System::nameservers)
		
		EventMachine::run do
			resolver.query('google.com') do |response|
				assert_equal RubyDNS::Message, response.class
				assert_equal Resolv::DNS::RCode::NoError, response.rcode
				
				EventMachine::stop
			end
		end
	end
	
	def test_hosts
		hosts = RubyDNS::System::Hosts.new
		
		# Load the test hosts data:
		File.open(File.expand_path("../hosts.txt", __FILE__)) do |file|
			hosts.parse_hosts(file)
		end
		
		assert hosts.call('testing')
		assert_equal '1.2.3.4', hosts['testing']
	end
end
