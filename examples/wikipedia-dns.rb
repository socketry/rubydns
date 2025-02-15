#!/usr/bin/env ruby
# encoding: utf-8

# Released under the MIT License.
# Copyright, 2014-2022, by Samuel Williams.
# Copyright, 2014, by Peter M. Goldstein.

# Released under the MIT License.
# Copyright, 2014-2022, by Samuel Williams.
# Copyright, 2014, by Peter M. Goldstein.

require "rubydns"

require "cgi"
require "json"

require "digest/md5"

require "async/http/client"
require "async/dns/extensions/string"
require "async/http/endpoint"

# Encapsulates the logic for fetching information from Wikipedia.
module Wikipedia
	ENDPOINT = Async::HTTP::Endpoint.parse("https://en.wikipedia.org")
	
	def self.lookup(title, logger: nil)
		client = Async::HTTP::Client.new(ENDPOINT)
		url = self.summary_url(title)
		
		logger&.debug "Making request to #{ENDPOINT} for #{url}."
		response = client.get(url, headers: {"user-agent" => "RubyDNS"})
		logger&.debug "Got response #{response.inspect}."
		
		if response.status == 301
			return lookup(response.headers["location"], logger: logger)
		else
			return self.extract_summary(response.body.read).force_encoding("ASCII-8BIT")
		end
	ensure
		response&.close
		client&.close
	end
	
	def self.summary_url(title)
		"/api/rest_v1/page/summary/#{CGI.escape title}"
	end

	def self.extract_summary(json_text)
		document = JSON.parse(json_text)
		
		return document["extract"]
	rescue
		return "Invalid Article."
	end
end

# A DNS server that queries Wikipedia and returns summaries for
# specifically crafted queries.
class WikipediaDNS
	Name = Resolv::DNS::Name
	IN = Resolv::DNS::Resource::IN
	
	INTERFACES = [
		[:udp, "::", 5300],
		[:tcp, "::", 5300],
	]

	def startup
		# Don't buffer output (for debug purposes)
		$stderr.sync = true

		stats = { requested: 0 }

		# Start the RubyDNS server
		RubyDNS.run_server(INTERFACES) do
			on(:start) do
				# Process::Daemon::Privileges.change_user(RUN_AS)
				
				@logger.info "Starting Wikipedia DNS..."
			end

			match(/stats\.wikipedia/, IN::TXT) do |transaction|
				transaction.respond!(*stats.inspect.chunked)
			end

			match(/(.+)\.wikipedia/, IN::TXT) do |transaction, match_data|
				title = match_data[1]
				stats[:requested] += 1
				
				summary = Wikipedia.lookup(title, logger: @logger)
				
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
