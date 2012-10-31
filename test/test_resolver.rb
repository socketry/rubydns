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
	
	class MockRequest
		attr :response
		
		def process_response!(response)
			@response = response
		end
	end
	
	def test_dirty_packets_udp
		mock_request = MockRequest.new
		
		handler_class = Class.new{ include RubyDNS::Resolver::Request::UDPRequestHandler }
		handler = handler_class.new(mock_request, nil, nil)
		
		handler.receive_data("This is not a real message!")
		
		assert_equal Resolv::DNS::DecodeError, mock_request.response.class
	end
	
	def test_dirty_packets_tcp
		mock_request = MockRequest.new
		
		handler_class = Class.new{ include RubyDNS::Resolver::Request::TCPRequestHandler }
		handler = handler_class.new(mock_request)
		
		data = "This is not a real message!"
		handler.receive_data([data.length].pack('n') + data)
		
		assert_equal Resolv::DNS::DecodeError, mock_request.response.class
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
