#!/usr/bin/env ruby

# Copyright, 2009, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'process/daemon'

require 'rubydns'
require 'rubydns/system'

INTERFACES = [
	[:udp, '0.0.0.0', 5300]
]

# A DNS server that selectively drops queries based on the requested domain
# name.  Queries for domains that match specified regular expresssions
# (like 'microsoft.com' or 'sco.com') return NXDomain, while all other
# queries are passed to upstream resolvers.
class FlakeyDNS < Process::Daemon
	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	def startup
		RubyDNS.run_server(listen: INTERFACES) do
			# Use a Celluloid supervisor so the system recovers if the actor dies
			fallback_resolver_supervisor =
			  RubyDNS::Resolver.supervise(RubyDNS::System.nameservers)

			# Fail the resolution of certain domains ;)
			match(/(m?i?c?r?o?s?o?f?t)/) do |transaction, match_data|
				if match_data[1].size > 7
					logger.info 'Dropping domain MICROSOFT...'
					transaction.fail!(:NXDomain)
				else
					# Pass the request to the otherwise handler
					false
				end
			end

			# Hmm....
			match(/^(.+\.)?sco\./) do |transaction|
				logger.info 'Dropping domain SCO...'
				transaction.fail!(:NXDomain)
			end

			# Default DNS handler
			otherwise do |transaction|
				logger.info 'Passing DNS request upstream...'
				transaction.passthrough!(fallback_resolver_supervisor.actors.first)
			end
		end
	end
end

FlakeyDNS.daemonize
