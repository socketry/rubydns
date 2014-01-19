#!/usr/bin/env ruby
# encoding: utf-8

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

require 'rexec'
require 'rexec/daemon'

require 'rubygems'

require 'rubydns'
require 'rubydns/extensions/string'

require 'digest/md5'

# You might need to change the user name "daemon". This can be a user name or a user id.
RUN_AS = "daemon"

if RExec.current_user != "root"
	$stderr.puts "Sorry, this command needs to be run as root!"
	exit 1
end

# To use, start the daemon and try:
# dig @localhost fortune CNAME
class FortuneDNS < RExec::Daemon::Base
	@@base_directory = File.dirname(__FILE__)

	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	def self.run
		# Don't buffer output (for debug purposes)
		$stderr.sync = true
		
		cache = {}
		stats = {:requested => 0}
		
		# Start the RubyDNS server
		RubyDNS::run_server do
			on(:start) do
				RExec.change_user(RUN_AS)
				if ARGV.include?("--debug")
					@logger.level = Logger::DEBUG
				else
					@logger.level = Logger::WARN
				end
			end
			
			match(/stats\.fortune/, IN::TXT) do |transaction|
				$stderr.puts "Sending stats: #{stats.inspect}"
				transaction.respond!(stats.inspect)
			end
			
			match(/(.+)\.fortune/, IN::TXT) do |transaction|
				fortune = cache[match[1]]
				stats[:requested] += 1
				
				if fortune
					transaction.respond!(*fortune.chunked)
				else
					transaction.fail!(:NXDomain)
				end
			end
			
			match(/fortune/, [IN::CNAME, IN::TXT]) do |transaction|
				fortune = `fortune`.gsub(/\s+/, " ").strip
				checksum = Digest::MD5.hexdigest(fortune)
				cache[checksum] = fortune
				
				transaction.respond!("Text Size: #{fortune.size} Byte Size: #{fortune.bytesize}", :resource_class => IN::TXT, :ttl => 0)
				transaction.respond!(Name.create(checksum + ".fortune"), :resource_class => IN::CNAME, :ttl => 0)
			end
			
			match(/short.fortune/, IN::TXT) do |match, transation|
				fortune = `fortune -s`.gsub(/\s+/, " ").strip
				
				transaction.respond!(*fortune.chunked, :ttl => 0)
			end
			
			# Default DNS handler
			otherwise do |transaction|
				transaction.fail!(:NXDomain)
			end
		end
	end
end

# RExec daemon runner
FortuneDNS.daemonize
