#!/usr/bin/env ruby

require 'helper'
require 'rubydns/resolver'

class ResolverTest < Test::Unit::TestCase
	def test_basic_resolver
		resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
		
		EventMachine::run do
			resolver.query('google.com') do |response|
				assert_equal RubyDNS::Message, response.class
				EventMachine::stop
			end
		end
		
		EventMachine::run do
			resolver.query('nonexistant.private') do |response|
				assert_equal response.rcode, Resolv::DNS::RCode::NXDomain
				EventMachine::stop
			end
		end
	end
	
	def test_broken_resolver
		resolver = RubyDNS::Resolver.new([])
		
		EventMachine::run do
			resolver.query('google.com') do |response|
				assert_equal RubyDNS::ResolutionFailure, response.class
				EventMachine::stop
			end
		end
	end
end
