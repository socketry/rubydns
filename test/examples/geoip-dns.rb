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

require 'rubygems'

require 'geoip'

require 'rexec'
require 'rexec/daemon'

require 'rubygems'
require 'rubydns'

require 'rubydns/resolver'
require 'rubydns/system'

INTERFACES = [
	[:udp, "0.0.0.0", 5300]
]

# This daemon requires the file downloaded from http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
# For more information, please see http://www.maxmind.com/en/geolite and http://geoip.rubyforge.org

class GeoIPDNSDaemon < RExec::Daemon::Base
	# You can specify a specific directory to use for run-time information (pid, logs, etc):
	# @@base_directory = File.expand_path("../", __FILE__)
	# @@base_directory = "/var"

	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN
	R = RubyDNS::Resolver.new(RubyDNS::System::nameservers)
	GEO = GeoIP.new(File.expand_path('../GeoLiteCountry.dat', __FILE__))
	
	def self.run
		RubyDNS::run_server(:listen => INTERFACES) do
			match(//, IN::A) do |transaction|
				location = nil
				peer = transaction.options[:peer]
				
				if peer
					logger.debug "Looking up geographic information for peer #{peer}"
					location = GEO.country(peer[0])
				end
				
				if location
					logger.debug "Found location #{location}"
				end
				
				case location.continent_code
				when "EU"
					transaction.respond!("1.1.1.1")
				when "CN", "JP"
					transaction.respond!("1.1.2.1")
				else
					transaction.respond!("1.1.3.1")
				end
			end

			# Default DNS handler
			otherwise do |transaction|
				transaction.passthrough!(R)
			end
		end
  end
end

GeoIPDNSDaemon.daemonize
