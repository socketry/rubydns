#!/usr/bin/env ruby

# Copyright (c) 2009, 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
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

require 'rexec'
require 'rexec/daemon'

require 'rubygems'
require 'rubydns'

require 'digest/md5'

# You might need to change the user name "daemon". This can be a user name or a user id.
RUN_AS = "daemon"

if RExec.current_user != "root"
	$stderr.puts "Sorry, this command needs to be run as root!"
	exit 1
end

# The Daemon itself
class FortuneDNS < RExec::Daemon::Base
	@@var_directory = File.dirname(__FILE__)

	def self.run
		# Don't buffer output (for debug purposes)
		$stderr.sync = true
		
		cache = {}
		stats = {:requested => 0}
		
		# Start the RubyDNS server
		RubyDNS::run_server do
			on(:start) do
				RExec.change_user(RUN_AS)
			end

			match(/(.*)\.fortune/, :TXT) do |match, transaction|
				fortune = cache[match[1]]
				stats[:requested] += 1
				
				if fortune
					transaction.respond!(fortune)
				else
					transaction.failure(:NXDomain)
				end
			end
			
			match(/stats.fortune/, :TXT) do |match, transaction|
				transaction.respond!(stats.inspect)
			end
			
			match(/fortune/, [:CNAME]) do |match, transaction|
				fortune = `fortune -s`.gsub(/\s+/, " ").strip
				checksum = Digest::MD5.hexdigest(fortune)
				cache[checksum] = fortune
				
				name = Resolv::DNS::Name.create(checksum + ".fortune")
				
				transaction.respond!(name, :resource_class => :CNAME, :ttl => 0)
			end
			
			# Default DNS handler
			otherwise do |transaction|
				transaction.failure!(:NXDomain)
			end
		end
	end
end

# RExec daemon runner
FortuneDNS.daemonize
