
require 'helper'
require 'pathname'

require 'rubydns'
require 'rubydns/resolver'
require 'rubydns/extensions/string'

class TruncatedServer < RExec::Daemon::Base
	@@base_directory = File.dirname(__FILE__)

	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	def self.run
		# Start the RubyDNS server
		RubyDNS::run_server(:listen => [[:udp, '0.0.0.0', 5320], [:tcp, '0.0.0.0', 5320]]) do
			match("truncation", IN::TXT) do |transaction|
				text = "Hello World! " * 100
				transaction.respond!(*text.chunked)
			end
			
			# Default DNS handler
			otherwise do |transaction|
				transaction.failure!(:NXDomain)
			end
		end
	end
end

class TruncationTest < Test::Unit::TestCase
	def setup
		TruncatedServer.start
	end
	
	def teardown
		TruncatedServer.stop
	end
	
	def test_tcp_failover
		resolver = RubyDNS::Resolver.new([[:udp, '127.0.0.1', 5320], [:tcp, '127.0.0.1', 5320]])
		
		EventMachine::run do
			resolver.query("truncation", IN::TXT) do |response|
				
				
				text = response.answer.first
				
				assert_equal "Hello World! " * 100, text[2].strings.join
				
				EventMachine::stop
			end
		end
	end
end
