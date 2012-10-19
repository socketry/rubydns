
require 'helper'
require 'pathname'

require 'rubydns'
require 'rubydns/resolver'

IN = Resolv::DNS::Resource::IN

class FortuneDNS < RExec::Daemon::Base
	@@base_directory = File.dirname(__FILE__)

	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	def self.run
		cache = {}
		stats = {:requested => 0}
		
		# Start the RubyDNS server
		RubyDNS::run_server(:listen => [[:udp, '0.0.0.0', 5300], [:tcp, '0.0.0.0', 5300]]) do
			match(/stats\.fortune/, IN::TXT) do |match, transaction|
				$stderr.puts "Sending stats: #{stats.inspect}"
				transaction.respond!(stats.inspect)
			end
			
			match(/(.+)\.fortune/, IN::TXT) do |match, transaction|
				fortune = cache[match[1]]
				stats[:requested] += 1
				
				if fortune
					transaction.respond!(*fortune.chunked)
				else
					transaction.failure!(:NXDomain)
				end
			end
			
			match(/fortune/, [IN::CNAME, IN::TXT]) do |match, transaction|
				fortune = `fortune`.gsub(/\s+/, " ").strip * 30
				checksum = Digest::MD5.hexdigest(fortune)
				cache[checksum] = fortune
				
				transaction.respond!("Text Size: #{fortune.size} Byte Size: #{fortune.bytesize}", :resource_class => IN::TXT, :ttl => 0)
				transaction.respond!(Name.create(checksum + ".fortune"), :resource_class => IN::CNAME, :ttl => 0)
			end
			
			# Default DNS handler
			otherwise do |transaction|
				transaction.failure!(:NXDomain)
			end
		end
	end
end

class DaemonTest < Test::Unit::TestCase
	def setup
		FortuneDNS.start
	end
	
	def teardown
		FortuneDNS.stop
	end
	
	def test_basic_dns
		resolver = RubyDNS::Resolver.new([[:udp, '127.0.0.1', 5300], [:tcp, '127.0.0.1', 5300]])
		
		EventMachine::run do
			resolver.query('fortune', IN::CNAME) do |response|
				stats = response.answer.find{|answer| IN::TXT === answer[2]}
				cname = response.answer.find{|answer| IN::CNAME === answer[2]}
				
				stats[2].strings.join.match(/Text Size: (\d+) Byte Size: (\d+)/)
				length = $2.to_i
				
				puts "Expecting #{length} bytes"
				
				puts cname[2].name
				
				resolver.query(cname[2].name, IN::TXT) do |response|
					text = response.answer.find{|answer| IN::TXT === answer[2]}
					
					puts stats[2].strings.inspect
					puts text[2].strings.join
					
					assert_equal length, text[2].strings.join.bytesize
					
					EventMachine::stop
				end
			end
		end
	end
end
