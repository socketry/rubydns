
require 'helper'
require 'pathname'

require 'rubydns'
require 'rubydns/resolver'
require 'rubydns/extensions/string'

class SlowServer < RExec::Daemon::Base
	SERVER_PORTS = [[:udp, '127.0.0.1', 5330], [:tcp, '127.0.0.1', 5330]]
	
	@@base_directory = File.dirname(__FILE__)

	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	def self.run
		RubyDNS::run_server(:listen => SERVER_PORTS) do
			match(/\.*.com/, IN::A) do |match, transaction|
				transaction.defer!
			
				# No domain exists, after 5 seconds:
				EventMachine::Timer.new(2) do
					transaction.failure!(:NXDomain)
				end
			end
		
			otherwise do |transaction|
				transaction.failure!(:NXDomain)
			end
		end
	end
end

class SlowServerTest < Test::Unit::TestCase
	def setup
		SlowServer.start
	end
	
	def teardown
		SlowServer.stop
	end
	
	def test_slow_request
		start_time = Time.now
		end_time = nil
		
		resolver = RubyDNS::Resolver.new(SlowServer::SERVER_PORTS, :timeout => 10)
		
		EventMachine::run do
			resolver.query("apple.com", IN::A) do |response|
				end_time = Time.now
				
				EventMachine::stop
			end
		end
		
		assert (end_time - start_time) > 2.0
	end
	
	def test_normal_request
		start_time = Time.now
		end_time = nil
		
		resolver = RubyDNS::Resolver.new(SlowServer::SERVER_PORTS, :timeout => 10)
		
		EventMachine::run do
			resolver.query("oriontransfer.org", IN::A) do |response|
				end_time = Time.now
				
				EventMachine::stop
			end
		end
		
		assert (end_time - start_time) < 2.0
	end
end
