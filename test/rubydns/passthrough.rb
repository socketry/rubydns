#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2012-2017, by Samuel Williams.

require "rubydns"

SERVER_PORTS = [[:udp, "127.0.0.1", 5340], [:tcp, "127.0.0.1", 5340]]
Name = Resolv::DNS::Name
IN = Resolv::DNS::Resource::IN

describe "RubyDNS Passthrough Server" do
	include_context Async::RSpec::Reactor
	
	def run_server
		task = RubyDNS::run_server(listen: SERVER_PORTS) do
			resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
		
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
		
		yield
		
	ensure
		task.stop
	end
	
	it "should resolve domain correctly" do
		run_server do
			resolver = RubyDNS::Resolver.new(SERVER_PORTS, timeout: 1)
			
			response = resolver.query("google.com")
			expect(response.ra).to be == 1
		
			answer = response.answer.first
			expect(answer).not_to be == nil
			expect(answer.count).to be > 0
		
			addresses = answer.select {|record| record.kind_of? Resolv::DNS::Resource::IN::A}
			expect(addresses.size).to be > 0
		end
	end

	it "should resolve prefixed domain correctly" do
		run_server do
			resolver = RubyDNS::Resolver.new(SERVER_PORTS)
		
			response = resolver.query("a-slashdot.org")
			answer = response.answer.first
		
			expect(answer).not_to be == nil
			expect(answer.count).to be > 0
		end
	end
end
