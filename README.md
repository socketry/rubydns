# RubyDNS

RubyDNS is a high-performance DNS server which can be easily integrated into other projects or used as a stand-alone daemon (via RExec). By default it uses rule-based pattern matching. Results can be hard-coded, computed, fetched from a remote DNS server or fetched from a local cache, depending on requirements.

In addition, RubyDNS includes a high-performance asynchronous DNS resolver built on top of EventMachine. This module can be used by itself in client applications without using the full RubyDNS server stack.

For examples and documentation please see the main [project page][1].

[1]: http://www.oriontransfer.co.nz/gems/rubydns

[![Build Status](https://secure.travis-ci.org/ioquatix/rubydns.png)](http://travis-ci.org/ioquatix/rubydns)
[![Code Climate](https://codeclimate.com/github/ioquatix/rubydns.png)](https://codeclimate.com/github/ioquatix/rubydns)

## Installation

Add this line to your application's Gemfile:

    gem 'rubydns'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rubydns

## Usage

This is copied from `test/examples/test-dns-2.rb`. It has been simplified slightly.

	#!/usr/bin/env ruby
	require 'rubydns'

	INTERFACES = [
		[:udp, "0.0.0.0", 53],
		[:tcp, "0.0.0.0", 53]
	]
	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	# Use upstream DNS for name resolution.
	UPSTREAM = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])

	def self.run
	    # Start the RubyDNS server
	    RubyDNS::run_server(:listen => INTERFACES) do
	        match(/test.mydomain.org/, IN::A) do |transaction|
	            transaction.respond!("10.0.0.80")
	        end

	        # Default DNS handler
	        otherwise do |transaction|
	            transaction.passthrough!(UPSTREAM)
	        end
	    end
	end
	run

Start the server using `rvmsudo ./test.rb`. You can then test it using dig:

	$ dig @localhost test1.mydomain.org
	$ dig @localhost dev.mydomain.org
	$ dig @localhost google.com

## Compatibility

### Migrating from RubyDNS 0.6.x to 0.7.x

The asynchronous deferred processing became the default and only method for processing requests in `0.7.0`. This simplifies the API but there were a few changes, notably the removal of `defer!` and the addition of `defer`. The reason for this was due to issues relating to deferred processing and the flow of control, which were confusing and introduced bugs in specific situations. Now, you can assume flow control through the entire block even with non-blocking functions.

	RubyDNS::run_server(:listen => SERVER_PORTS) do
		match(/\.*.com/, IN::A) do |transaction|
			# Won't block and won't continue until handle.resume is called.
			defer do |fiber|
				# No domain exists, after 5 seconds:
				EventMachine::Timer.new(5) do
					transaction.fail!(:NXDomain)
					
					fiber.resume
				end
			end
		end

		otherwise do
			transaction.fail!(:NXDomain)
		end
	end

You can see a complete example in `test/test_slow_server.rb`.

#### Server structure changes

When integrating RubyDNS into another project, the rule based DSL is often a hurdle rather than a feature. Thus, the rule-based DSL component of `RubyDNS::Server` class has been separated into a derived `RubyDNS::RuleBasedServer` class. `RubyDNS::Server` can be derived and the `RubyDNS::Server#process` method can be overridden to provide a single entry point for DNS processing.

In addition, `RubyDNS::Server#run` can now start the server, provided you are within an `EventMachine#run` context. The existing entry point, `RubyDNS::run_server` provides the same rule-based DSL as previous versions.

#### Method name changes

Some method names have changed to improve consistency.

- `failure!` became `fail!`
- `append` became `add`
- `append_query!` became `append!`

### Migrating from RubyDNS 0.5.x to 0.6.x

The order of arguments to pattern based rules has changed. For regular expression based rules, the arguments are now ordered `|transaction, match_data|`. The main reason for this change was that in many cases match_data is not important and can thus be ignored, e.g. `|transaction|`.

Going forward, Ruby 1.8.x is no longer supported.

### Migrating from RubyDNS 0.4.x to 0.5.x

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

### Migrating from RubyDNS 0.3.x to 0.4.x

Due to changes in `resolv.rb`, superficial parts of RubyDNS have changed. Rather than using `:A` to specify A-records, one must now use the class name.

	match(..., :A)

becomes

	IN = Resolv::DNS::Resource::IN
	match(..., IN::A)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

### Desired Features

* Support for more features of DNS such as zone transfer.
* Support reverse records more easily.

## License

Released under the MIT license.

Copyright, 2009, 2012, 2014, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

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
