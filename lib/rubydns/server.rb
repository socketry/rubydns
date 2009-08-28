# Copyright (c) 2009 Samuel Williams. Released under the GNU GPLv3.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'rubydns/transaction'

module RubyDNS
	
	# This class provides the core of the DSL. It contains a list of rules which
	# are used to match against incoming DNS questions. These rules are used to
	# generate responses which are either DNS resource records or failures.
	class Server
		
		# Instantiate a server with a block
		#
		#   server = Server.new do
		#     match(/server.mydomain.com/, :A) do |transaction|
		#       transaction.respond!("1.2.3.4")
		#     end
		#   end
		#
		def initialize(&block)
			@rules = []
			@otherwise = nil

			@logger = Logger.new($stderr)

			if block_given?
				instance_eval &block
			end
		end

		attr :logger, true

		# This function connects a pattern with a block. A pattern is either
		# a String or a Regex instance. Optionally, a second argument can be
		# provided which is either a String, Symbol or Array of resource record
		# types which the rule matches against.
		# 
		#   match("www.google.com")
		#   match("gmail.com", :MX)
		#   match(/g?mail.(com|org|net)/, [:MX, :A])
		#
		def match (*pattern, &block)
			# Normalize pattern
			case pattern[1]
			when nil
				# Do nothing
			when String
				pattern[1] = pattern[1].upcase
			when Symbol
				pattern[1] = pattern[1].to_s.upcase
			when Array
				pattern[1] = pattern[1].collect { |v| v.to_s.upcase }
			end

			@rules << [pattern, Proc.new(&block)]
		end

		# Specify a default block to execute if all other rules fail to match.
		# This block is typially used to pass the request on to another server
		# (i.e. recursive request).
		#
		#   otherwise do |transaction|
		#     transaction.passthrough!($R)
		#   end
		#
		def otherwise(&block)
			@otherwise = Proc.new(&block)
		end

		# Give a name and a record type, try to match a rule and use it for
		# processing the given arguments.
		#
		# If a rule returns false, it is considered that the rule failed and
		# futher matching is carried out.
		def process(name, record_type, *args)
			@logger.debug "Searching for #{name} #{record_type}"

			@rules.each do |rule|
				@logger.debug "Checking rule #{rule[0].inspect}..."
				
				pattern = rule[0]

				# Match failed against record_type?
				case pattern[1]
				when String
					next if pattern[1] != record_type.upcase
					@logger.debug "Resource type #{record_type} matched"
				when Array
					next if pattern[1].include?(record_type.upcase)
					@logger.debug "Resource type #{record_type} matched #{pattern[1].inspect}"
				end

				# Match succeeded against name?
				case pattern[0]
				when Regexp
					match_data = pattern[0].match(name)
					if match_data
						@logger.debug "Query #{name} matched #{pattern[0].to_s} with result #{match_data.inspect}"
						if rule[1].call(match_data, *args)
							@logger.debug "Rule returned successfully"
							return
						end
					else
						@logger.debug "Query #{name} failed to match against #{pattern[0].to_s}"
					end
				when String
					if pattern[0] == name
						@logger.debug "Query #{name} matched #{pattern[0]}"
						if rule[1].call(*args)
							@logger.debug "Rule returned successfully"
							return
						end
					else
						@logger.debug "Query #{name} failed to match against #{pattern[0]}"
					end
				end
			end

			if @otherwise
				@otherwise.call(*args)
			else
				@logger.warn "Failed to handle #{name} #{record_type}!"
			end
		end

		# Process an incoming DNS message. Returns a serialized message to be
		# sent back to the client.
		def receive_data(data)
			query = Resolv::DNS::Message::decode(data)

			# Setup answer
			answer = Resolv::DNS::Message::new(query.id)
			answer.qr = 1                 # 0 = Query, 1 = Response
			answer.opcode = query.opcode  # Type of Query; copy from query
			answer.aa = 1                 # Is this an authoritative response: 0 = No, 1 = Yes
			answer.rd = query.rd          # Is Recursion Desired, copied from query
			answer.ra = 0                 # Does name server support recursion: 0 = No, 1 = Yes
			answer.rcode = 0              # Response code: 0 = No errors

			query.each_question do |question, resource_class|    # There may be multiple questions per query
				transaction = Transaction.new(self, query, question, resource_class, answer)

				begin
					process(transaction.name, transaction.record_type, transaction)
				rescue
					@logger.error "Exception thrown while processing #{transaction}!"
					@logger.error "#{$!.class}: #{$!.message}"
					$!.backtrace.each { |at| @logger.error at }

					answer.rcode = Resolv::DNS::RCode::ServFail
				end
			end

			return answer.encode
		end
	end
end
