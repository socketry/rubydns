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
		# This issue was not fixed in 1.9.3 but the proposed patch works as expected:
		# https://bugs.ruby-lang.org/issues/4788
		def fetch_resource(name, typeclass)
			lazy_initialize
			requester = make_udp_requester
			senders = {}
			begin
				@config.resolv(name) {|candidate, tout, nameserver, port|
					msg = Message.new
					msg.rd = 1
					msg.add_question(candidate, typeclass)
					unless sender = senders[[candidate, nameserver, port]]
						sender = senders[[candidate, nameserver, port]] =
						requester.sender(msg, candidate, nameserver, port)
					end
					reply, reply_name = requester.request(sender, tout)
					case reply.rcode
					when RCode::NoError
						if reply.tc == 1 and not Requester::TCP === requester
							requester.close
							# Retry via TCP:
							requester = make_tcp_requester(nameserver, port)
							senders = {}
							# This will use TCP for all remaining candidates (assuming the
							# current candidate does not already respond successfully via
							# TCP).  This makes sense because we already know the full
							# response will not fit in an untruncated UDP packet.
							redo
						else
							yield(reply, reply_name)
						end
						return
					when RCode::NXDomain
						raise Config::NXDomain.new(reply_name.to_s)
					else
						raise Config::OtherResolvError.new(reply_name.to_s)
					end
				}
			ensure
				requester.close
			end
		end

		def each_resource(name, typeclass, &proc)
			fetch_resource(name, typeclass) do |reply, reply_name|
				extract_resources(reply, reply_name, typeclass, &proc)
			end
		end

		# Queries the given DNS server and returns its response in its entirety.
		# This allows such responses to be passed upstream with little or no
		# modification/reinterpretation.
		def query(name, typeclass)
			fetch_resource(name, typeclass) do |reply, reply_name|
				return reply, reply_name
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

				@question += other.question
				@answer += other.answer
				@authority += other.authority
				@additional += other.additional

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