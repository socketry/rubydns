# RubyDNS
[![Gitter](https://badges.gitter.im/Join Chat.svg)](https://gitter.im/ioquatix/rubydns?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

RubyDNS is a high-performance DNS server which can be easily integrated into other projects or used as a stand-alone daemon. By default it uses rule-based pattern matching. Results can be hard-coded, computed, fetched from a remote DNS server or fetched from a local cache, depending on requirements.

In addition, RubyDNS includes a high-performance asynchronous DNS resolver built on top of [Celluloid][1]. This module can be used by itself in client applications without using the full RubyDNS server stack.

For examples and documentation please see the main [project page][2].

[1]: https://celluloid.io
[2]: http://www.codeotaku.com/projects/rubydns/

[![Build Status](https://travis-ci.org/ioquatix/rubydns.svg?branch=master)](https://travis-ci.org/ioquatix/rubydns)
[![Code Climate](https://codeclimate.com/github/ioquatix/rubydns.png)](https://codeclimate.com/github/ioquatix/rubydns)
[![Coverage Status](https://coveralls.io/repos/ioquatix/rubydns/badge.svg?branch=master)](https://coveralls.io/r/ioquatix/rubydns?branch=master)

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
		[:udp, "0.0.0.0", 5300],
		[:tcp, "0.0.0.0", 5300]
	]
	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	# Use upstream DNS for name resolution.
	UPSTREAM = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])

	# Start the RubyDNS server
	RubyDNS::run_server(:listen => INTERFACES) do
		match(/test\.mydomain\.org/, IN::A) do |transaction|
			transaction.respond!("10.0.0.80")
		end

		# Default DNS handler
		otherwise do |transaction|
			transaction.passthrough!(UPSTREAM)
		end
	end

Start the server using `./test.rb`. You can then test it using dig:

	$ dig @localhost -p 5300 test.mydomain.org
	$ dig @localhost -p 5300 google.com

### File Handle Limitations

On some platforms (e.g. Mac OS X) the number of file descriptors is relatively low by default and should be increased by calling `ulimit -n 10000` before running tests or even before starting a server which expects a large number of concurrent incoming connections.

### Custom servers

It is possible to create and integrate your own custom servers.

	class MyServer < RubyDNS::Server
		def process(name, resource_class, transaction)
			transaction.fail!(:NXDomain)
		end
	end
	
	# Use the RubyDNS infrastructure for running the daemon:
	# If asynchronous is true, it will return immediately, otherwise, it will block the current thread until Ctrl-C is pressed (SIGINT).
	RubyDNS::run_server(asynchronous: false, server_class: MyServer)
	
	# Directly instantiate the celluloid supervisor:
	supervisor = MyServer.supervise
	supervisor.actors.first.run

This is the best way to integrate with other projects.

## Performance

We welcome additional benchmarks and feedback regarding RubyDNS performance. To check the current performance results, consult the [travis build job output](https://travis-ci.org/ioquatix/rubydns).

### Server

The performance is on the same magnitude as `bind9`. Some basic benchmarks resolving 1000 names concurrently, repeated 5 times, using `RubyDNS::Resolver` gives the following:

	                           user     system      total        real
	RubyDNS::Server        4.280000   0.450000   4.730000 (  4.854862)
	Bind9                  4.970000   0.520000   5.490000 (  5.541213)

These benchmarks are included in the unit tests. To test bind9 performance, it must be installed and `which named` must return the executable.

### Resolver

The `RubyDNS::Resolver` is highly concurrent and can resolve individual names as fast as the built in `Resolv::DNS` resolver. Because the resolver is asynchronous, when dealing with multiple names, it can work more efficiently:

	                           user     system      total        real
	RubyDNS::Resolver      0.020000   0.010000   0.030000 (  0.030507)
	Resolv::DNS            0.070000   0.010000   0.080000 (  1.465975)

These benchmarks are included in the unit tests.

### DNSSEC support

DNSSEC is currently not supported and is [unlikely to be supported in the future](http://sockpuppet.org/blog/2015/01/15/against-dnssec/).

## Compatibility

### Migrating from RubyDNS 0.8.x to 0.9.x

RubyDNS 0.9.0 is based on a branch which replaced EventMachine with Celluloid. This reduces the complexity in writing concurrent systems hugely, but it is also a largely untested code path. RubyDNS 0.8.x using EventMachine has been tested over 4 years now by many projects.

The reason for the change is simply that EventMachine is now a dead project and no longer being maintained/supported. The ramifications of this are: no IPv6 support, crashes/segfaults in certain workloads with no workable solution going forward, and lack of integration with external libraries.

The difference for authors integrating RubyDNS in a daemon should be minimal. For users integrating RubyDNS into an existing system, you need to be aware of the contracts imposed by Celluloid, namely, whether it affects other parts of your system. Some areas of Celluloid are well developed, others are still needing attention (e.g. how it handles forking child processes). We expect the 0.8 branch should remain stable for a long time, but 0.9 branch will eventually become the 1.0 release.

The benefits of using Celluloid include: fault tolerance, high performance, scalability across multiple hardware threads (when using Rubinius or JRuby), simpler integration with 3rd party data (e.g. `defer` has now been removed since it isn't necessary with celluloid).

### Migrating from RubyDNS 0.7.x to 0.8.x

The primary change is the removal of the dependency on `RExec` which was used for daemons and the addition of the testing dependency `process-daemon`. In order to create and run your own daemon, you may use `process-daemon` or another tool of your choice.

The transaction options are now conveniently available:

	transaction.options[key] == transaction[key]

The remote peer address used to be available directly via `transaction[:peer]` but profiling revealed that the `EventMachine::Connection#get_peername` was moderately expensive. Therefore, the incoming connection is now available in `transaction[:connection]` and more specifically `transaction[:peer]` is no longer available and replaced by `transaction[:connection].peername` which gives `[ip_address, port]`.

### Migrating from RubyDNS 0.6.x to 0.7.x

The asynchronous deferred processing became the default and only method for processing requests in `0.7.0`. This simplifies the API but there were a few changes, notably the removal of `defer!` and the addition of `defer`. The reason for this was due to issues relating to deferred processing and the flow of control, which were confusing and introduced bugs in specific situations. Now, you can assume flow control through the entire block even with non-blocking functions.

	RubyDNS::run_server(:listen => SERVER_PORTS) do
		match(/\.*.com/, IN::A) do |transaction|
			# Won't block and won't continue until fiber.resume is called.
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
* Some kind of system level integration, e.g. registering a DNS server with the currently running system resolver.

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
