#!/usr/bin/env ruby

# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'minitest/autorun'

require 'rubydns'
require 'process/daemon'

require 'benchmark'

class ServerPerformanceRubyDNS < Process::Daemon
	IN = Resolv::DNS::Resource::IN
	
	def working_directory
		File.expand_path("../tmp", __FILE__)
	end
	
	def startup
		million = {}
		
		puts "Generating domains..."
		(1..5_000).each do |i|
			domain = "domain#{i}.local"
	
			million[domain] = "#{69}.#{(i >> 16)%256}.#{(i >> 8)%256}.#{i%256}"
		end
		
		puts "Starting DNS server..."
		RubyDNS::run_server(:listen => [[:udp, '0.0.0.0', 5300]]) do
			@logger.level = Logger::WARN
			
			match(//, IN::A) do |transaction|
				puts "Responding to #{transaction.name}"
				transaction.respond!(million[transaction.name])
			end
		
			# Default DNS handler
			otherwise do |transaction|
				transaction.fail!(:NXDomain)
			end
		end
	end
end

class ServerPerformanceBind9 < Process::Daemon
	def working_directory
		File.expand_path("../performance/bind9", __FILE__)
	end
	
	def startup
		exec(self.class.named_executable, "-c", "named.conf", "-f", "-p", "5400", "-g")
	end
	
	def self.named_executable
		# Check if named executable is available:
		@named ||= `which named`.chomp
	end
end

class ServerPerformanceTest < MiniTest::Test
	DOMAINS = (1..2000).collect do |i|
		"domain#{i}.local"
	end
	
	def setup
		@servers = []
		@servers << ["RubyDNS::Server", 5300]
		
		# Increase the maximum number of file descriptors:
		`ulimit -n 8000`
		
		ServerPerformanceRubyDNS.start
		
		unless ServerPerformanceBind9.named_executable.empty?
			ServerPerformanceBind9.start
			@servers << ["Bind9", 5400]
		end
		
		# Give the daemons some time to start up:
		sleep 2
	end
	
	def teardown
		ServerPerformanceRubyDNS.stop
		
		unless ServerPerformanceBind9.named_executable.empty?
			ServerPerformanceBind9.stop
		end
	end
	
	def test_server_performance
		resolved = {}
		
		puts nil, "Testing server performance..."
		Benchmark.bm(20) do |x|
			@servers.each do |name, port|
				x.report(name) do
					resolver = RubyDNS::Resolver.new([[:udp, '127.0.0.1', port]])
		
					# Number of requests remaining since this is an asynchronous event loop:
					pending = DOMAINS.size
		
					EventMachine::run do
						DOMAINS.each do |domain|
							resolver.addresses_for(domain) do |addresses|
								resolved[domain] = addresses
					
								EventMachine::stop if (pending -= 1) == 0
							end
						end
					end
				end
			end
		end
	end
end
