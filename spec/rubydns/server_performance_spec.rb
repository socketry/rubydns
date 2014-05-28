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

require 'rubydns'
require 'benchmark'
require 'process/daemon'

module RubyDNS::ServerPerformanceSpec
	describe RubyDNS::Server do
		context 'benchmark' do
			class ServerPerformanceRubyDNS < Process::Daemon
				IN = Resolv::DNS::Resource::IN
	
				def working_directory
					File.expand_path("../tmp", __FILE__)
				end
	
				def startup
					puts "Booting celluloid..."
					Celluloid.boot
				
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
					File.expand_path("../server/bind9", __FILE__)
				end
	
				def startup
					exec(self.class.named_executable, "-c", "named.conf", "-f", "-p", "5400", "-g")
				end
	
				def self.named_executable
					# Check if named executable is available:
					@named ||= `which named`.chomp
				end
			end
		
			before do
				Celluloid.shutdown
			
				@servers = []
				@servers << ["RubyDNS::Server", 5300]
			
				@domains = (1..1000).collect do |i|
					"domain#{i}.local"
				end
			
				ServerPerformanceRubyDNS.start
			
				unless ServerPerformanceBind9.named_executable.empty?
					ServerPerformanceBind9.start
					@servers << ["Bind9", 5400]
				end
				
				sleep 2
				
				Celluloid.boot
			end
		
			after do
				ServerPerformanceRubyDNS.stop
			
				unless ServerPerformanceBind9.named_executable.empty?
					ServerPerformanceBind9.stop
				end
			end
		
			it 'it takes time' do
				Celluloid.logger.level = Logger::ERROR
			
				Benchmark.bm(20) do |x|
					@servers.each do |name, port|
						resolver = RubyDNS::Resolver.new([[:udp, '127.0.0.1', port]])
					
						x.report(name) do
							# Number of requests remaining since this is an asynchronous event loop:
							5.times do
								pending = @domains.size
							
								futures = @domains.collect{|domain| resolver.future.addresses_for(domain)}
							
								futures.collect do |future|
									expect(future.value).to_not be nil
								end
							end
						end
					end
				end
			end
		end
	end
end
