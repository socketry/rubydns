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

# Resolv rdoc
# http://www.ruby-doc.org/stdlib/libdoc/resolv/rdoc/index.html

require 'resolv'

class Resolv
	class DNS
		# Queries the given DNS server and returns its response in its entirety.
		# This allows such responses to be passed upstream with little or no
		# modification/reinterpretation.
		def query(name, typeclass)
			lazy_initialize
			requester = make_requester
			senders = {}
			begin
				@config.resolv(name) {|candidate, tout, nameserver|
					msg = Message.new
					msg.rd = 1
					msg.add_question(candidate, typeclass)
					unless sender = senders[[candidate, nameserver]]
						sender = senders[[candidate, nameserver]] =
						requester.sender(msg, candidate, nameserver)
					end
					reply, reply_name = requester.request(sender, tout)

					return reply, reply_name
				}
			ensure
				requester.close
			end
		end

		class Message
			# Merge the given message with this message. A number of heuristics are
			# applied in order to ensure that the result makes sense. For example,
			# If the current message is not recursive but is being merged with a
			# message that was recursive, this bit is maintained. If either message
			# is authoritive, then the result is also authoritive.
			#
			# Modifies the current message in place.
			def merge! (other)
				# Authoritive Answer
				@aa = @aa && other.aa

				@additional += other.additional
				@answer += other.answer
				@authority += other.authority
				@question += other.question

				# Recursion Available
				@ra = @ra || other.ra

				# Result Code (Error Code)
				@rcode = other.rcode unless other.rcode == 0

				# Recursion Desired
				@rd = @rd || other.rd
			end
		end
	end
end