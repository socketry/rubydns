# RubyDNS

RubyDNS is a high-performance DNS server which can be easily integrated into other projects or used as a stand-alone daemon. By default it uses rule-based pattern matching. Results can be hard-coded, computed, fetched from a remote DNS server or fetched from a local cache, depending on requirements.

[![Development Status](https://github.com/socketry/rubydns/workflows/Test/badge.svg)](https://github.com/socketry/rubydns/actions?workflow=Test)

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

``` ruby
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

``` ruby
class MyServer < Async::DNS::Server
	def process(name, resource_class, transaction)
		transaction.fail!(:NXDomain)
	end
end

Async::Reactor.run do
	task = MyServer.new.run
	
	# ... do other things, e.g. run specs/tests
	
	# Shut down the server manually if required, otherwise it will run indefinitely.
	# task.stop
end
```

This is the best way to integrate with other projects.

## Performance

**Due to changes in the underlying code, there have been some very minor performance regressions. The numbers below will be updated in due course.**

We welcome additional benchmarks and feedback regarding RubyDNS performance. To check the current performance results, consult the [travis build job output](https://travis-ci.org/ioquatix/rubydns).

### Server

The performance is on the same magnitude as `bind9`. Some basic benchmarks resolving 1000 names concurrently, repeated 5 times, using `RubyDNS::Resolver` gives the following:

``` 
                           user     system      total        real
RubyDNS::Server        4.280000   0.450000   4.730000 (  4.854862)
Bind9                  4.970000   0.520000   5.490000 (  5.541213)
```

These benchmarks are included in the unit tests. To test bind9 performance, it must be installed and `which named` must return the executable.

### Resolver

The `RubyDNS::Resolver` is highly concurrent and can resolve individual names as fast as the built in `Resolv::DNS` resolver. Because the resolver is asynchronous, when dealing with multiple names, it can work more efficiently:

``` 
                           user     system      total        real
RubyDNS::Resolver      0.020000   0.010000   0.030000 (  0.030507)
Resolv::DNS            0.070000   0.010000   0.080000 (  1.465975)
```

These benchmarks are included in the unit tests.

### DNSSEC support

DNSSEC is currently not supported and is [unlikely to be supported in the future](http://sockpuppet.org/blog/2015/01/15/against-dnssec/).

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.

## See Also

The majority of this gem is now implemented by `async-dns`.

  - [async-io](https://github.com/socketry/async-io) — Asynchronous networking and sockets.
  - [async-dns](https://github.com/socketry/async-dns) — Asynchronous DNS resolver and server.
  - [async-rspec](https://github.com/socketry/async-rspec) — Shared contexts for running async specs.
