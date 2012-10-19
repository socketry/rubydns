
require 'helper'
require 'pathname'

require 'rubydns'
require 'rubydns/resolver'

require 'rexec'
require 'rexec/daemon'

Name = Resolv::DNS::Name
IN = Resolv::DNS::Resource::IN

class TestServer < RExec::Daemon::Base
	@@base_directory = File.dirname(__FILE__)

	def self.run
		resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
		
		# Start the RubyDNS server
		RubyDNS::run_server(:listen => [[:udp, "0.0.0.0", 5300], [:tcp, "0.0.0.0", 5300]]) do
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
		TestServer.start
	end
	
	def teardown
		TestServer.stop
	end
	
	def test_basic_dns
		answer = nil
		
		assert_equal :running, RExec::Daemon::ProcessFile.status(TestServer)
		
		EventMachine.run do
			resolver = RubyDNS::Resolver.new([[:udp, "127.0.0.1", 5300], [:tcp, "127.0.0.1", 5300]])
		
			resolver.query("google.com") do |response|
				answer = response.answer.first
				
				EventMachine.stop
			end
		end
		
		assert answer.count > 0
	end
end
