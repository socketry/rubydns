RubyDNS
=======

* Released under the MIT license.
* Copyright (C) 2009, 2011 [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams/).
* [![Build Status](https://secure.travis-ci.org/ioquatix/rubydns.png)](http://travis-ci.org/ioquatix/rubydns)

RubyDNS is a simple programmatic DSL (domain specific language) for configuring and running a DNS server. RubyDNS provides a daemon that runs a DNS server which can process DNS requests depending on specific policy. Rule selection is based on pattern matching, and results can be hard-coded, computed, fetched from a remote DNS server, fetched from a local cache, etc.

RubyDNS provides a full daemon server using RExec. You can either use the built in daemon, customize it to your needs, or specify a full daemon implementation.

RubyDNS is not designed to be high-performance and uses a thread-per-request model. This is designed to make it as easy as possible to achieve concurrent performance. This is also due to the fact that many other APIs work best this way (unfortunately).

For examples please see the main [project page][1].

[1]: http://www.oriontransfer.co.nz/gems/rubydns

Basic Example
-------------

This is copied from `test/example1.rb`. It has been simplified slightly.

	require 'rubygems'
	require 'rubydns'

	$R = Resolv::DNS.new

	RubyDNS::run_server do
		Name = Resolv::DNS::Name
		IN = Resolv::DNS::Resource::IN
		
		# For this exact address record, return an IP address
		match("dev.mydomain.org", IN::A) do |transaction|
			transaction.respond!("10.0.0.80")
		end

		match(/^test([0-9]+).mydomain.org$/, IN::A) do |match_data, transaction|
			offset = match_data[1].to_i

			if offset > 0 && offset < 10
				logger.info "Responding with address #{"10.0.0." + (90 + offset).to_s}..."
				transaction.respond!("10.0.0." + (90 + offset).to_s)
			else
				logger.info "Address out of range: #{offset}!"
				false
			end
		end

		# Default DNS handler
		otherwise do |transaction|
			logger.info "Passing DNS request upstream..."
			transaction.passthrough!($R)
		end
	end

After starting this server you can test it using dig:

	dig @localhost test1.mydomain.org
	dig @localhost dev.mydomain.org
	dig @localhost google.com

Compatibility
-------------

### Migrating from RubyDNS 0.3.x to 0.4.x ###

Due to changes in `resolv.rb`, superficial parts of RubyDNS have changed. Rather than using `:A` to specify A-records, one must now use the class name.

	match(..., :A)

becomes

	IN = Resolv::DNS::Resource::IN
	match(..., IN::A)

### Migrating from RubyDNS 0.4.x to 0.5.x ###

The system standard resolver was synchronous, and this could stall the server when making upstream requests to other DNS servers. A new resolver `RubyDNS::Resolver` now provides an asynchronous interface and the `Transaction::passthrough` makes exclusive use of this to provide high performance asynchonous resolution.

Here is a basic example of how to use the new resolver in full. It is important to provide both `:udp` and `:tcp` connection specifications, so that large requests will be handled correctly:

	resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
	
	EventMachine::run do
		resolver.query('google.com', IN::A) do |response|
			case response
			when RubyDNS::Message
				puts "Got response: #{response.answers.first}"
			else
				# Response is of class RubyDNS::ResolutionFailure
				puts "Failed: #{response.message}"
			end
			
			EventMachine::stop
		end
	end

Existing code that uses `Resolv::DNS` as a resolver will need to be updated:

	# 1/ Add this at the top of your file; Host specific system information:
	require 'rubydns/system'
	
	# 2/ Change from R = Resolv::DNS.new to:
	R = RubyDNS::Resolver.new(RubyDNS::System::nameservers)

Everything else in the server can remain the same. You can see a complete example in `test/test_resolver.rb`.

#### Deferred Transactions ####

The implementation of the above depends on a new feature which was added in 0.5.0:

	transaction.defer!

Once you call this, the transaction won't complete until you call either `transaction.succeed` or `transaction.fail`.

	RubyDNS::run_server(:listen => SERVER_PORTS) do
		match(/\.*.com/, IN::A) do |match, transaction|
			transaction.defer!
			
			# No domain exists, after 5 seconds:
			EventMachine::Timer.new(5) do
				transaction.failure!(:NXDomain)
			end
		end
		
		otherwise do
			transaction.failure!(:NXDomain)
		end
	end

You can see a complete example in `test/test_slow_server.rb`.

Todo
----

* Support for more features of DNS such as zone transfer.
* Support reverse records more easily.

License
-------

Copyright (c) 2010, 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
