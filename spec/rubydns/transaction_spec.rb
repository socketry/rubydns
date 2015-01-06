#!/usr/bin/env rspec

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
require 'yaml'

module RubyDNS::TransactionSpec
	SERVER_PORTS = [[:udp, '8.8.8.8', 53], [:tcp, '8.8.8.8', 53]]
	IN = Resolv::DNS::Resource::IN
	
	describe RubyDNS::Transaction do
		let(:server) { RubyDNS::Server.new }
		let(:query) { RubyDNS::Message.new(0) }
		let(:question) { Resolv::DNS::Name.create("www.google.com.") }
		let(:response) { RubyDNS::Message.new(0) }
		let(:resolver) { RubyDNS::Resolver.new([[:udp, '8.8.8.8', 53], [:tcp, '8.8.8.8', 53]])}
		
		it "should append an address" do
			transaction = RubyDNS::Transaction.new(server, query, question, IN::A, response)
			
			transaction.respond!("1.2.3.4")
			
			expect(transaction.response.answer[0][0]).to be == question
			expect(transaction.response.answer[0][2].address.to_s).to be == "1.2.3.4"
		end
		
		it "should passthrough the request" do
			transaction = RubyDNS::Transaction.new(server, query, question, IN::A, response)
			
			expect(transaction.response.answer.size).to be 0
			
			transaction.passthrough!(resolver)
			
			expect(transaction.response.answer.size).to be > 0
		end
		
		it "should return a response on passthrough" do
			transaction = RubyDNS::Transaction.new(server, query, question, IN::A, response)
			
			expect(transaction.response.answer.size).to be 0
			
			response = transaction.passthrough(resolver)
			
			expect(response.answer.length).to be > 0
		end
		
		it "should call the block with the response when invoking passthrough!" do
			transaction = RubyDNS::Transaction.new(server, query, question, IN::A, response)
			
			expect(transaction.response.answer.size).to be 0
			
			passthrough_response = nil
			
			transaction.passthrough!(resolver) do |response|
				passthrough_response = response
			end
			
			expect(passthrough_response.answer.length).to be > 0
		end
		
		it "should fail the request" do
			transaction = RubyDNS::Transaction.new(server, query, question, IN::A, response)
			
			transaction.fail! :NXDomain
			
			expect(transaction.response.rcode).to be Resolv::DNS::RCode::NXDomain
		end
		
		it "should return AAAA record" do
			transaction = RubyDNS::Transaction.new(server, query, question, IN::AAAA, response)
			
			expect(transaction.response.answer.size).to be 0
			
			transaction.passthrough!(resolver)
			
			expect(transaction.response.answer.first[2]).to be_kind_of IN::AAAA
		end
		
		it "should return MX record" do
			transaction = RubyDNS::Transaction.new(server,query,"google.com",IN::MX, response)
			
			expect(transaction.response.answer.size).to be 0
			
			transaction.passthrough!(resolver)
			
			expect(transaction.response.answer.first[2]).to be_kind_of IN::MX
		end
		
		it "should return NS record" do
			transaction = RubyDNS::Transaction.new(server, query, "google.com", IN::NS, response)
			
			expect(transaction.response.answer.size).to be 0
			
			transaction.passthrough!(resolver)
			
			expect(transaction.response.answer.first[2]).to be_kind_of IN::NS
		end
		
		it "should return PTR record" do
			transaction = RubyDNS::Transaction.new(server, query, "8.8.8.8.in-addr.arpa", IN::PTR, response)
			
			expect(transaction.response.answer.size).to be 0
			
			transaction.passthrough!(resolver)
			
			expect(transaction.response.answer.first[2]).to be_kind_of IN::PTR
		end
		
		it "should return SOA record" do
			transaction = RubyDNS::Transaction.new(server, query, "google.com", IN::SOA, response)
			
			expect(transaction.response.answer.size).to be 0
			
			transaction.passthrough!(resolver)
			
			expect(transaction.response.answer.first[2]).to be_kind_of IN::SOA
		end
	end
end
