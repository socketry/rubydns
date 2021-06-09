#!/usr/bin/env ruby
require 'rubydns'

INTERFACES = [
	[:udp, "0.0.0.0", 5300],
	[:tcp, "0.0.0.0", 5300],
]

# Use upstream DNS for name resolution.
UPSTREAM = RubyDNS::Resolver.new([
	[:udp, "8.8.8.8", 53],
	[:tcp, "8.8.8.8", 53]
])

$R = Resolv::DNS.new
Name = Resolv::DNS::Name
IN = Resolv::DNS::Resource::IN

# Start the RubyDNS server
RubyDNS::run_server(INTERFACES) do
	@logger.debug!
  
  #match google.com
  match(/^google.com$/, IN::A) do |transaction|
    transaction.respond!(Name.create('forcesafesearch.google.com'), resource_class: IN::CNAME)
  end
  match(/^www.google.com$/, IN::A) do |transaction|
    transaction.respond!(Name.create('forcesafesearch.google.com'), resource_class: IN::CNAME)
  end

	otherwise do |transaction|
		transaction.passthrough!(UPSTREAM)
	end
end

