
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
			match(/.*\.com/, IN::A) do |match, transaction|
				transaction.passthrough!(resolver)
			end

			# Default DNS handler
			otherwise do |transaction|
				transaction.failure!(:NXDomain)
			end
		end
	end
end

class PassthroughTest < Test::Unit::TestCase
	def setup
		TestPassthroughServer.start
	end
	
	def teardown
		TestPassthroughServer.stop
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
		
		assert answer.count > 0
	end
end
