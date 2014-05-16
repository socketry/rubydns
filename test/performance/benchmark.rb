#!/usr/bin/env ruby

require 'benchmark'
require 'rubydns'

Benchmark.bm(20) do |x|
	DOMAINS = (1..1000).collect do |i|
		"domain#{i}.local"
	end
	
	resolved = {}
	
	x.report("RubyDNS::Resolver") do
		resolver = RubyDNS::Resolver.new([[:udp, '127.0.0.1', 5300]])
		
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