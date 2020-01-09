#!/usr/bin/env ruby
require 'rubydns'

INTERFACES = [
	[:udp, "127.0.0.2", 53],
	[:tcp, "127.0.0.2", 53],
]

# Use upstream DNS for name resolution.
UPSTREAM = RubyDNS::Resolver.new([
	[:udp, "8.8.8.8", 53],
	[:tcp, "8.8.8.8", 53]
])

# Start the RubyDNS server
RubyDNS::run_server(INTERFACES) do
	@logger.debug!
	
	otherwise do |transaction|
		transaction.passthrough!(UPSTREAM)
	end
end