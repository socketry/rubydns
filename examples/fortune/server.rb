#!/usr/bin/env ruby

# Released under the MIT License.
# Copyright, 2014, by Samuel Williams.
# Copyright, 2014, by Peter M. Goldstein.

require "rubydns"
require "async/dns/extensions/string"
require "digest/md5"

Name = Resolv::DNS::Name
IN = Resolv::DNS::Resource::IN

endpoint = Async::DNS::Endpoint.for("localhost", port: 5300)

stats = {requested: 0}
cache = {}

# Start the RubyDNS server
RubyDNS.run(endpoint) do
	match(/short\.fortune/, IN::TXT) do |transaction|
		fortune = `fortune -s`.gsub(/\s+/, " ").strip
		
		transaction.respond!(*fortune.chunked, ttl: 0)
	end
	
	match(/stats\.fortune/, IN::TXT) do |transaction|
		$stderr.puts "Sending stats: #{stats.inspect}"
		transaction.respond!(stats.inspect)
	end
	
	match(/([a-f0-9]*)\.fortune/, IN::TXT) do |transaction, match|
		fortune = cache[match[1]]
		stats[:requested] += 1
		
		if fortune
			transaction.respond!(*fortune.chunked)
		else
			transaction.fail!(:NXDomain)
		end
	end
	
	match(/fortune/, [IN::CNAME, IN::TXT]) do |transaction|
		fortune = `fortune`.gsub(/\s+/, " ").strip
		checksum = Digest::MD5.hexdigest(fortune)
		cache[checksum] = fortune
		
		answer_txt = "Text Size: #{fortune.size} Byte Size: #{fortune.bytesize}"
		transaction.respond!(answer_txt, resource_class: IN::TXT, ttl: 0)
		answer_cname = Name.create(checksum + ".fortune")
		transaction.respond!(answer_cname, resource_class: IN::CNAME, ttl: 0)
	end

	# Default DNS handler
	otherwise do |transaction|
		transaction.fail!(:NXDomain)
	end
end
