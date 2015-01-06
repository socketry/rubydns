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

require 'resolv'

class Resolv
	class DNS
		class Message
			# Merge the given message with this message. A number of heuristics are applied in order to ensure that the result makes sense. For example, If the current message is not recursive but is being merged with a message that was recursive, this bit is maintained. If either message is authoritive, then the result is also authoritive.
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
		
		class OriginError < ArgumentError
		end
		
		class Name
			def to_s
				"#{@labels.join('.')}#{@absolute ? '.' : ''}"
			end
			
			def inspect
				"#<#{self.class}: #{self.to_s}>"
			end
			
			# Return the name, typically absolute, with the specified origin as a suffix. If the origin is nil, don't change the name, but change it to absolute (as specified).
			def with_origin(origin, absolute = true)
				return self.class.new(@labels, absolute) if origin == nil
				
				origin = Label.split(origin) if String === origin
				
				return self.class.new(@labels + origin, absolute)
			end
			
			
			# Return the name, typically relative, without the specified origin suffix. If the origin is nil, don't change the name, but change it to absolute (as specified).
			def without_origin(origin, absolute = false)
				return self.class.new(@labels, absolute) if origin == nil
				
				origin = Label.split(origin) if String === origin
				
				if @labels.last(origin.length) == origin
					return self.class.new(@labels.first(@labels.length - origin.length), absolute)
				else
					raise OriginError.new("#{self} does not end with #{origin.join('.')}")
				end
			end
		end
	end
end