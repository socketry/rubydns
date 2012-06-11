RubyDNS
=======

* Author: Samuel G. D. Williams (<http://www.oriontransfer.co.nz>)
* Copyright (C) 2009, 2011 Samuel G. D. Williams.
* Released under the MIT license.

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

From RubyDNS version `0.4.0`, the recommended minimum Ruby version is `1.9.3` for complete support. Some features may not work as expected on Ruby version `1.8.x` and it is not tested significantly.

### Migrating from RubyDNS 0.3.x to 0.4.x ###

Due to changes in `resolv.rb`, superficial parts of RubyDNS have changed. Rather than using `:A` to specify A-records, one must now use the class name.

	match(..., :A)

becomes

	IN = Resolv::DNS::Resource::IN
	match(..., IN::A)

Todo
----

* Support for more features of DNS such as zone transfer
* Support reverse records more easily
* Better support for deferred requests/concurrency.

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
