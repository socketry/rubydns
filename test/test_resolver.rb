#!/usr/bin/env ruby

require 'helper'
require 'rubydns'

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
	
	def test_addresses_for
		resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
		resolved_addresses = nil
		
		EventMachine::run do
			resolver.addresses_for("www.google.com.") do |addresses|
				resolved_addresses = addresses
				
				EventMachine::stop
			end
		end
		
		assert resolved_addresses.count > 0
		
		address = resolved_addresses[0]
		assert address.kind_of?(Resolv::IPv4) || address.kind_of?(Resolv::IPv6)
	end
end
