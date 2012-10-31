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

begin
	require 'win32/resolv'
rescue LoadError
	# Ignore this - we aren't running on windows.
end

module RubyDNS
	# This module encapsulates system dependent name lookup functionality.
	module System
		RESOLV_CONF = "/etc/resolv.conf"
		HOSTS = "/etc/hosts"

		def self.hosts_path
			if RUBY_PLATFORM =~ /mswin32|mingw|bccwin/
				Win32::Resolv.get_hosts_path
			else
				HOSTS
			end
		end

		# This code is very experimental
		class Hosts
			def initialize
				@addresses = {}
				@names = {}
			end

			attr :addresses
			attr :names

			# This is used to match names against the list of known hosts:
			def call(name)
				@names.include?(name)
			end

			def lookup(name)
				addresses = @names[name]

				if addresses
					addresses.last
				else
					nil
				end
			end

			alias [] lookup

			def add(address, names)
				@addresses[address] ||= []
				@addresses[address] += names

				names.each do |name|
					@names[name] ||= []
					@names[name] << address
				end
			end

			def parse_hosts(io)
				io.each do |line|
					line.sub!(/#.*/, '')
					address, hostname, *aliases = line.split(/\s+/)

					add(address, [hostname] + aliases)
				end
			end

			def self.local
				hosts = self.new

				path = System::hosts_path

				if path and File.exist?(path)
					File.open(path) do |file|
						hosts.parse_hosts(file)
					end
				end

				return hosts
			end
		end

		def self.parse_resolv_configuration(path)
			nameservers = []
			File.open(path) do |file|
				file.each do |line|
					# Remove any comments:
					line.sub!(/[#;].*/, '')

					# Extract resolv.conf command:
					keyword, *args = line.split(/\s+/)

					case keyword
					when 'nameserver'
						nameservers += args
					end
				end
			end

			return nameservers
		end

		def self.standard_connections(nameservers)
			connections = []

			nameservers.each do |host|
				connections << [:udp, host, 53]
				connections << [:tcp, host, 53]
			end

			return connections
		end

		# Get a list of standard nameserver connections which can be used for querying any standard servers that the system has been configured with. There is no equivalent facility to use the `hosts` file at present.
		def self.nameservers
			nameservers = []

			if File.exist? RESOLV_CONF
				nameservers = parse_resolv_configuration(RESOLV_CONF)
			elsif defined?(Win32::Resolv) and RUBY_PLATFORM =~ /mswin32|cygwin|mingw|bccwin/
				search, nameservers = Win32::Resolv.get_resolv_info
			end

			return standard_connections(nameservers)
		end
	end
end
