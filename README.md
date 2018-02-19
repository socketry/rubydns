# RubyDNS

RubyDNS is a high-performance DNS server which can be easily integrated into other projects or used as a stand-alone daemon. By default it uses rule-based pattern matching. Results can be hard-coded, computed, fetched from a remote DNS server or fetched from a local cache, depending on requirements.

[![Build Status](https://travis-ci.org/socketry/rubydns.svg)](https://travis-ci.org/socketry/rubydns)
[![Code Climate](https://codeclimate.com/github/socketry/rubydns.svg)](https://codeclimate.com/github/socketry/rubydns)
[![Coverage Status](https://coveralls.io/repos/socketry/rubydns/badge.svg)](https://coveralls.io/r/socketry/rubydns)
[![Gitter](https://badges.gitter.im/join.svg)](https://gitter.im/socketry/rubydns)

[![RubyDNS Introduction](http://img.youtube.com/vi/B9ygq0xh3HQ/maxresdefault.jpg)](https://www.youtube.com/watch?v=B9ygq0xh3HQ&feature=youtu.be&hd=1 "RubyDNS Introduction")

## Installation

Add this line to your application's Gemfile:

	gem 'rubydns'

And then execute:

	$ bundle

Or install it yourself as:

	$ gem install rubydns

## Usage

There are [lots of examples available](examples/README.md) in the `examples/` directory.

### Basic DNS Server

Here is the code from `examples/basic-dns.rb`:

```ruby
#!/usr/bin/env ruby
require 'rubydns'

INTERFACES = [
	[:udp, "0.0.0.0", 5300],
	[:tcp, "0.0.0.0", 5300],
]

IN = Resolv::DNS::Resource::IN

# Use upstream DNS for name resolution.
UPSTREAM = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])

# Start the RubyDNS server
RubyDNS::run_server(INTERFACES) do
	match(%r{test.local}, IN::A) do |transaction|
		transaction.respond!("10.0.0.80")
	end

	# Default DNS handler
	otherwise do |transaction|
		transaction.passthrough!(UPSTREAM)
	end
end
```

Start the server using `RUBYOPT=-w ./examples/basic-dns.rb`. You can then test it using dig:

	$ dig @localhost -p 5300 test.local
	$ dig @localhost -p 5300 google.com

### File Handle Limitations

On some platforms (e.g. Mac OS X) the number of file descriptors is relatively low by default and should be increased by calling `ulimit -n 10000` before running tests or even before starting a server which expects a large number of concurrent incoming connections.

### Custom Servers

It is possible to create and integrate your own custom servers, however this functionality has now moved to [`Async::DNS::Server`](https://github.com/socketry/async-dns).

```ruby
class MyServer < Async::DNS::Server
	def process(name, resource_class, transaction)
		transaction.fail!(:NXDomain)
	end
end

Async::Reactor.run do
	task = MyServer.new.run
	
	# ... do other things
	
	# Shut down the server:
	task.stop
end
```

This is the best way to integrate with other projects.

## Performance

**Due to changes in the underlying code, there have been some very minor performance regressions. The numbers below will be updated in due course.**

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

## See Also

The majority of this gem is now implemented by `async-dns`.

- [async-io](https://github.com/socketry/async-io) — Asynchronous networking and sockets.
- [async-dns](https://github.com/socketry/async-dns) — Asynchronous DNS resolver and server.
- [async-rspec](https://github.com/socketry/async-rspec) — Shared contexts for running async specs.

## License

Released under the MIT license.

Copyright, 2017, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

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
