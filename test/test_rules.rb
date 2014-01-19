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

class RulesTest < Test::Unit::TestCase
	IN = Resolv::DNS::Resource::IN
	
	def setup
		@server = RubyDNS::Server.new
		@true_callback = Proc.new { true }
	end
	
	def teardown
	end
	
	def test_string_pattern
		rule = RubyDNS::RuleBasedServer::Rule.new(["foobar", IN::A], @true_callback)
		
		assert rule.call(@server, "foobar", IN::A)
		assert !rule.call(@server, "barfoo", IN::A)
		assert !rule.call(@server, "foobar", IN::TXT)
	end
	
	def test_regexp_pattern
		rule = RubyDNS::RuleBasedServer::Rule.new([/foo/, IN::A], @true_callback)
		
		assert rule.call(@server, "foobar", IN::A)
		assert !rule.call(@server, "barbaz", IN::A)
		assert !rule.call(@server, "foobar", IN::TXT)
	end
	
	def test_callback_pattern
		calls = 0
		
		callback = Proc.new do |name, resource_class|
			# A counter used to check the number of times this block was invoked.
			calls += 1
			
			name.size == 6
		end
		
		rule = RubyDNS::RuleBasedServer::Rule.new([callback], @true_callback)
		
		assert rule.call(@server, "foobar", IN::A)
		assert !rule.call(@server, "foobarbaz", IN::A)
		
		assert_equal 2, calls
	end
end
