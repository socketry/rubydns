# Getting Started

This guide explains how to get started running your own DNS server with RubyDNS.

## Installation

Create a new directory for your project, with a gemfile, and then add the gem to your project:

~~~ bash
$ bundle add rubydns
~~~

## Usage

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
