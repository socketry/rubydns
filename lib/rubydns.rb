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

require_relative 'rubydns/version'

require_relative 'rubydns/message'
require_relative 'rubydns/server'
require_relative 'rubydns/resolver'
require_relative 'rubydns/handler'
require_relative 'rubydns/logger'

module RubyDNS
	# Run a server with the given rules.
	def self.run_server (options = {}, &block)
		server_class = options[:server_class] || RuleBasedServer
		
		supervisor = server_class.supervise(options, &block)
		
		supervisor.actors.first.run
		if options[:asynchronous]
			return supervisor
		else
			read, write = IO.pipe
			
			trap(:INT) {
				write.puts
			}
			
			IO.select([read])
			supervisor.terminate
		end
	end
end
