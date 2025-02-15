#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2014, by Peter M. Goldstein.
# Copyright, 2014-2017, by Samuel Williams.

require "rubydns"
require "async/dns/extensions/string"

class TestServer < RubyDNS::RuleBasedServer
	def test_message
		"Testing..."
	end
end

SERVER_PORTS = [[:udp, "127.0.0.1", 5520]]
IN = Resolv::DNS::Resource::IN

describe "RubyDNS::run_server(server_class: ...)" do
	include_context Async::RSpec::Reactor
	
	let(:server) do
		# Start the RubyDNS server
		RubyDNS::run_server(SERVER_PORTS, server_class: TestServer) do
			match("test_message", IN::TXT) do |transaction|
				transaction.respond!(*test_message.chunked)
			end
			
			# Default DNS handler
			otherwise do |transaction|
				transaction.fail!(:NXDomain)
			end
		end
	end
	
	it "should use the injected class" do
		task = server
		
		resolver = RubyDNS::Resolver.new(SERVER_PORTS)
		response = resolver.query("test_message", IN::TXT)
		text = response.answer.first
		expect(text[2].strings.join).to be == "Testing..."
		
		task.stop
	end
end
