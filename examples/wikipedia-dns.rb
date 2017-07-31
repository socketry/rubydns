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

require 'cgi'
require 'nokogiri'
require 'json'

require 'digest/md5'

require 'async/logger'
require 'async/http/client'
require 'async/dns/extensions/string'

# Encapsulates the logic for fetching information from Wikipedia.
module Wikipedia
	def self.server_host
		"http://www.wikipedia.org"
	end
	
	def self.summary_url(title)
		"/?action=parse&page=#{CGI.escape title}&prop=text&section=0&format=json"
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
class WikipediaDNS
	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN

	def startup
		# Don't buffer output (for debug purposes)
		$stderr.sync = true

		stats = { requested: 0 }

		# Start the RubyDNS server
		RubyDNS.run_server([[:udp, '0.0.0.0', 5300], [:tcp, '0.0.0.0', 5300]]) do
			on(:start) do
				# Process::Daemon::Privileges.change_user(RUN_AS)
				
				if ARGV.include?('--debug')
					@logger.level = Logger::DEBUG
				else
					@logger.level = Logger::WARN
				end
				
				@logger.info "Starting Wikipedia DNS..."
			end

			match(/stats\.wikipedia/, IN::TXT) do |transaction|
				transaction.respond!(*stats.inspect.chunked)
			end

			match(/(.+)\.wikipedia/, IN::TXT) do |transaction, match_data|
				title = match_data[1]
				stats[:requested] += 1

				wikipedia_endpoint = Async::IO::Endpoint.tcp('198.35.26.96', 80)
				client = Async::HTTP::Client.new(wikipedia_endpoint)
				url = Wikipedia.summary_url(title)
				
				@logger.info "Making request to #{wikipedia_endpoint} for #{url}."
				response = client.get(url, {'Host' => 'www.wikipedia.org'})
				@logger.info "Got response #{response.inspect}."
				
				summary =
					Wikipedia.extract_summary(response.body).force_encoding('ASCII-8BIT')
				transaction.respond!(*summary.chunked)
			end

			# Default DNS handler
			otherwise do |transaction|
				transaction.fail!(:NXDomain)
			end
		end
	end
end

wikipedia_dns = WikipediaDNS.new
wikipedia_dns.startup
