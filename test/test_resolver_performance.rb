#!/usr/bin/env ruby

# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'minitest/autorun'

require 'rubydns'
require 'rubydns/system'

require 'benchmark'

class ResolverPerformanceTest < MiniTest::Test
	# The larger this number, the better RubyDNS::Resolver will look as it is highly asynchronous.
	DOMAINS = DATA.readlines.collect{|line| line.chomp!}.flatten
	
	def test_resolvers
		rubydns_resolved = {}
		resolv_resolved = {}
		
		Benchmark.bm(20) do |x|
			x.report("RubyDNS::Resolver") do
				resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
				
				# Number of requests remaining since this is an asynchronous event loop:
				pending = DOMAINS.size
				
				EventMachine::run do
					DOMAINS.each do |domain|
						resolver.addresses_for(domain) do |addresses|
							rubydns_resolved[domain] = addresses
							
							EventMachine::stop if (pending -= 1) == 0
						end
					end
				end
			end
			
			x.report("Resolv::DNS") do
				resolver = Resolv::DNS.new(:nameserver => "8.8.8.8")
				
				DOMAINS.each do |domain|
					resolv_resolved[domain] = resolver.getaddresses(domain)
				end
			end
		end
		
		DOMAINS.each do |domain|
			# We don't really care if the responses aren't identical - they should be most of the time but due to the way DNS works this isn't always the case:
			refute_empty resolv_resolved[domain]
			refute_empty rubydns_resolved[domain]
		end
	end
end

__END__
Facebook.com
Twitter.com
Google.com
Youtube.com
Wordpress.org
Adobe.com
Blogspot.com
Wikipedia.org
Linkedin.com
Wordpress.com
Yahoo.com
Amazon.com
Flickr.com
Pinterest.com
Tumblr.com
W3.org
Apple.com
Myspace.com
Vimeo.com
Microsoft.com
Youtu.be
Qq.com
Digg.com
Baidu.com
Stumbleupon.com
Addthis.com
Statcounter.com
Feedburner.com
TradeMe.co.nz
Delicious.com
Nytimes.com
Reddit.com
Weebly.com
Bbc.co.uk
Blogger.com
Msn.com
Macromedia.com
Goo.gl
Instagram.com
Gov.uk
Icio.us
Yandex.ru
Cnn.com
Webs.com
Google.de
T.co
Livejournal.com
Imdb.com
Mail.ru
Jimdo.com
