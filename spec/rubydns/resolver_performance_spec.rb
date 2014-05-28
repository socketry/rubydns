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

require 'rubydns'

module RubyDNS::ResolverPerformanceSpec
	describe RubyDNS::Resolver do
		context 'benchmark' do
			domains = %W{
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
			}
		
			before do
				require 'benchmark'
			end
		
			it 'should be faster than native resolver' do
				Celluloid.logger.level = Logger::ERROR
			
				Benchmark.bm(20) do |x|
					a = x.report("RubyDNS::Resolver") do
						resolver = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
					
						futures = domains.collect{|domain| resolver.future.addresses_for(domain)}
					
						futures.collect{|future| future.value}
					end
			
					b = x.report("Resolv::DNS") do
						resolver = Resolv::DNS.new(:nameserver => "8.8.8.8")
				
						resolved = domains.collect do |domain|
							[domain, resolver.getaddresses(domain)]
						end
					end
				
					expect(a.real).to be < b.real
				end
			end
		end
	end
end
