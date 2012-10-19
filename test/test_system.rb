
require 'helper'
require 'pathname'

require 'rubydns'
require 'rubydns/system'

require 'rexec'

class SystemTest < Test::Unit::TestCase
	def test_system_nameservers
		# There technically should be at least one nameserver:
		resolver = RubyDNS::Resolver.new(RubyDNS::System::nameservers)
		
		EventMachine::run do
			resolver.query('google.com') do |response|
				assert_equal RubyDNS::Message, response.class
				assert_equal Resolv::DNS::RCode::NoError, response.rcode
				
				EventMachine::stop
			end
		end
	end
	
	def test_hosts
		hosts = RubyDNS::System::Hosts.new
		
		# Load the test hosts data:
		File.open(File.expand_path("../hosts.txt", __FILE__)) do |file|
			hosts.parse_hosts(file)
		end
		
		assert hosts.call('testing')
		assert_equal '1.2.3.4', hosts['testing']
	end
end
