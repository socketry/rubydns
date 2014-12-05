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

require 'rubydns'
require 'rubydns/extensions/string'

require 'process/daemon'
require 'process/daemon/privileges'

require 'cgi'
require 'nokogiri'
require 'json'

require 'digest/md5'

# You might need to change the user name "daemon". This can be a user name
# or a user id.
RUN_AS = 'daemon'

if Process::Daemon::Privileges.current_user != 'root'
	$stderr.puts 'Sorry, this command needs to be run as root!'
	exit 1
end

require 'http'

# Celluloid::IO fetcher to retrieve URLs.
class HttpFetcher
	include Celluloid::IO

	def get(url)
		# Note: For SSL support specify:
		# 	ssl_socket_class: Celluloid::IO::SSLSocket
		HTTP.get(url, socket_class: Celluloid::IO::TCPSocket)
	end
end

# Encapsulates the logic for fetching information from Wikipedia.
module Wikipedia
	def self.summary_url(title)
		"http://en.wikipedia.org/w/api.php?action=parse&page=#{CGI.escape title}&prop=text&section=0&format=json"
	end

	def self.extract_summary(json_text)
		document = JSON.parse(json_text)
		return Nokogiri::HTML(document['parse']['text']['*']).css('p')[0].text
	rescue
		return 'Invalid Article.'
	end
end

# A DNS server that queries Wikipedia and returns summaries for
# specifically crafted queries.
class WikipediaDNS < Process::Daemon
	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	def startup
		# Don't buffer output (for debug purposes)
		$stderr.sync = true

		stats = { requested: 0 }

		# Use a Celluloid supervisor so the system recovers if the actor dies
		fetcher = HttpFetcher.supervise

		# Start the RubyDNS server
		RubyDNS.run_server do
			on(:start) do
				Process::Daemon::Privileges.change_user(RUN_AS)
				if ARGV.include?('--debug')
					@logger.level = Logger::DEBUG
				else
					@logger.level = Logger::WARN
				end
			end

			match(/stats\.wikipedia/, IN::TXT) do |transaction|
				transaction.respond!(*stats.inspect.chunked)
			end

			match(/(.+)\.wikipedia/, IN::TXT) do |transaction, match_data|
				title = match_data[1]
				stats[:requested] += 1

				response = fetcher.actors.first.get(Wikipedia.summary_url(title))

				summary =
					Wikipedia.extract_summary(response).force_encoding('ASCII-8BIT')
				transaction.respond!(*summary.chunked)
			end

			# Default DNS handler
			otherwise do |transaction|
				transaction.fail!(:NXDomain)
			end
		end
	end
end

WikipediaDNS.daemonize
