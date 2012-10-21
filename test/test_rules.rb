
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
		rule = RubyDNS::Server::Rule.new(["foobar", IN::A], @true_callback)
		
		assert rule.call(@server, "foobar", IN::A)
		assert !rule.call(@server, "barfoo", IN::A)
		assert !rule.call(@server, "foobar", IN::TXT)
	end
	
	def test_regexp_pattern
		rule = RubyDNS::Server::Rule.new([/foo/, IN::A], @true_callback)
		
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
		
		rule = RubyDNS::Server::Rule.new([callback], @true_callback)
		
		assert rule.call(@server, "foobar", IN::A)
		assert !rule.call(@server, "foobarbaz", IN::A)
		
		assert_equal 2, calls
	end
end
