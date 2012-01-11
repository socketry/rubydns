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