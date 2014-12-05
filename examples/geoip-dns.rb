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

require 'geoip'

require 'process/daemon'

require 'rubydns'
require 'rubydns/system'

INTERFACES = [
	[:udp, '0.0.0.0', 5300]
]

# Path to the GeoIP file downloaded from
# http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
# If you have renamed the ungzipped file, or have placed it somewhere other than
# the repository root directory you will need to update this path.
PATH_TO_GEOIP_DAT_FILE =
	File.expand_path('../GeoIP.dat', File.dirname(__FILE__))

# A sample DNS daemon that demonstrates how to use RubyDNS to build responses
# that vary based on the geolocation of the requesting peer.  Clients of
# this server who request A records will get an answer IP address based
# on the continent of the client IP address.
#
# Please note that use of this example requires that the peer have a public
# IP address.  IP addresses on private networks or the localhost IP (127.0.0.1)
# cannot be resolved to a location, and so will always yield the unknown result.
# This daemon requires the file downloaded from
# http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
# For more information, please see http://www.maxmind.com/en/geolite and
# http://geoip.rubyforge.org
class GeoIPDNS < Process::Daemon
	GEO = GeoIP.new(PATH_TO_GEOIP_DAT_FILE)

	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	def startup
		RubyDNS.run_server(listen: INTERFACES) do
			fallback_resolver_supervisor =
			  RubyDNS::Resolver.supervise(RubyDNS::System.nameservers)
			match(//, IN::A) do |transaction|
				logger.debug 'In block'

				# The IP Address of the peer is stored in the transaction options
				# with the key :peer
				ip_address = transaction.options[:peer]
				logger.debug "Looking up geographic information for peer #{ip_address}"
				location = GeoIPDNS.ip_to_location(ip_address)

				if location
					logger.debug "Found location #{location} for #{ip_address}"
				else
					logger.debug "Could not resolve location for #{ip_address}"
				end

				code = location ? location.continent_code : nil
				answer = GeoIPDNS.answer_for_continent_code(code)
				logger.debug "Answer is #{answer}"
				transaction.respond!(answer)
			end

			# Default DNS handler
			otherwise do |transaction|
				logger.debug 'In otherwise'
				transaction.passthrough!(fallback_resolver_supervisor.actors.first)
			end
		end
	end

	# Maps each continent code to a fixed IP address for the response.
	# A simple mapper to demonstrate the behavior.
	def self.answer_for_continent_code(code)
		case code
		when 'AF' then '1.1.1.1'
		when 'AN' then '1.1.2.1'
		when 'AS' then '1.1.3.1'
		when 'EU' then '1.1.4.1'
		when 'NA' then '1.1.5.1'
		when 'OC' then '1.1.6.1'
		when 'SA' then '1.1.7.1'
		else '1.1.8.1'
		end
	end

	# Finds the continent code for the specified IP address.
	# Returns nil if the IP address cannot be mapped to a location.
	def self.ip_to_location(ip_address)
		return nil unless ip_address
		GEO.country(ip_address)
	end
end

GeoIPDNS.daemonize
