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

module RubyDNS::RulesSpec
	describe RubyDNS::RuleBasedServer do
		IN = Resolv::DNS::Resource::IN

		true_callback = Proc.new { true }

		it "should match string patterns correctly" do
			server = double(:logger => Logger.new("/dev/null"))
			transaction = double(:query => Resolv::DNS::Message.new(0))

			rule = RubyDNS::RuleBasedServer::Rule.new(["foobar", IN::A], true_callback)

			expect(rule.call(server, "foobar", IN::A, transaction)).to be == true
			expect(rule.call(server, "barfoo", IN::A, transaction)).to be == false
			expect(rule.call(server, "foobar", IN::TXT, transaction)).to be == false
		end

		it "should match regular expression patterns correctly" do
			server = double(:logger => Logger.new("/dev/null"))
			transaction = double(:query => Resolv::DNS::Message.new(0))

			rule = RubyDNS::RuleBasedServer::Rule.new([/foo/, IN::A], true_callback)

			expect(rule.call(server, "foobar", IN::A, transaction)).to be == true
			expect(rule.call(server, "barbaz", IN::A, transaction)).to be == false
			expect(rule.call(server, "foobar", IN::TXT, transaction)).to be == false
		end

		it "should match callback patterns correctly" do
			server = double(:logger => Logger.new("/dev/null"))
			transaction = double(:query => Resolv::DNS::Message.new(0))

			calls = 0

			callback = Proc.new do |name, resource_class|
				# A counter used to check the number of times this block was invoked.
				calls += 1
	
				name.size == 6
			end

			rule = RubyDNS::RuleBasedServer::Rule.new([callback], true_callback)

			expect(rule.call(server, "foobar", IN::A, transaction)).to be == true
			expect(rule.call(server, "foobarbaz", IN::A, transaction)).to be == false

			expect(calls).to be == 2
		end
	end
end
