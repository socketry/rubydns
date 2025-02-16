# RubyDNS

RubyDNS is a high-performance DNS server which can be easily integrated into other projects or used as a stand-alone daemon. By default it uses rule-based pattern matching. Results can be hard-coded, computed, fetched from a remote DNS server or fetched from a local cache, depending on requirements.

[![Development Status](https://github.com/socketry/rubydns/workflows/Test/badge.svg)](https://github.com/socketry/rubydns/actions?workflow=Test)

## Installation

Add the gem to your project:

~~~ bash
$ bundle add rubydns
~~~

## Usage

There are examples in the `examples` directory which demonstrate how to use RubyDNS.

### Simple DNS Server

This example demonstrates how to create a simple DNS server that responds to `test.local A` and forwards all other requests to the system default resolver.

``` ruby
#!/usr/bin/env ruby
require 'rubydns'

# Use the system default resolver for upstream queries:
upstream = Async::DNS::Resolver.default

# We will use port 5300 so we don't need to run the server as root:
endpoint = Async::DNS::Endpoint.for("localhost", port: 5300)

# Start the RubyDNS server:
RubyDNS.run(endpoint) do
	match(%r{test.local}, Resolv::DNS::Resource::IN::A) do |transaction|
		transaction.respond!("10.0.0.80")
	end

	# Default DNS handler
	otherwise do |transaction|
		transaction.passthrough!(upstream)
	end
end
```

### Custom Servers

It is possible to create and integrate your own custom servers, however this functionality has now moved to [`Async::DNS::Server`](https://github.com/socketry/async-dns).

``` ruby
class MyServer < Async::DNS::Server
	def process(name, resource_class, transaction)
		transaction.fail!(:NXDomain)
	end
end

Async do
	task = MyServer.new.run
	
	# ... do other things, e.g. run specs/tests
	
	# Shut down the server manually if required, otherwise it will run indefinitely.
	# task.stop
end
```

This is the best way to integrate with other projects.

### DNSSEC support

DNSSEC is currently not supported and is [unlikely to be supported in the future](http://sockpuppet.org/blog/2015/01/15/against-dnssec/).

## See Also

The majority of this gem is now implemented by `async-dns`.

  - [async-dns](https://github.com/socketry/async-dns) — Asynchronous DNS resolver and server.

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
