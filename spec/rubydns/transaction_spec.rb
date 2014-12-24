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
require 'yaml'

module RubyDNS::TransactionSpec
	SERVER_PORTS = [[:udp, '8.8.8.8', 53], [:tcp, '8.8.8.8', 53]]
	IN = Resolv::DNS::Resource::IN
	
	describe RubyDNS::Transaction do
		let(:server) { RubyDNS::Server.new }
		let(:query) { RubyDNS::Message.new(0) }
		let(:question) { Resolv::DNS::Name.create("www.google.com") }
		let(:response) { RubyDNS::Message.new(0) }
		let(:resolver) { RubyDNS::Resolver.new([[:udp, '8.8.8.8', 53], [:tcp, '8.8.8.8', 53]])}
		
		it "should append an address" do
			transaction = RubyDNS::Transaction.new(server, query, question, IN::A, response)
			
			transaction.respond!("1.2.3.4")
			
			expect(transaction.response.answer[0][0].to_s).to be == question.to_s
			expect(transaction.response.answer[0][2].address.to_s).to be == "1.2.3.4"
		end
		
		it "should passthrough the request" do
			transaction = RubyDNS::Transaction.new(server, query, question, IN::A, response)
			
			expect(transaction.response.answer.size).to be 0
			
			transaction.passthrough!(resolver)
			
			expect(transaction.response.answer.size).to be > 0
		end

                it "should return a block on passthrough! if requested" do                                                                                                                                                                                                      
                        transaction = RubyDNS::Transaction.new(server, query, question, IN::A, response)                                                                                                                                                                       
                        response_object = ''                                                                                                                                                                                                                                   
                        response_name = ''
                        expect(transaction.response.answer.size).to be 0                                                                                                                                                                                                       
                                                                                                                                                                                                                                                                               
                        transaction.passthrough!(resolver) do | reply |                                                                                                                                                                                           
                           response_object = reply                                                                                                                                                                                                                             
                        end                                                                                                                                                                                                                                                    
                        expect(response_object.answer.length).to be > 0  
                end
 
                it "should return a block on passthrough if requested" do
                
			transaction = RubyDNS::Transaction.new(server, query, question, IN::A, response)
                        response_object = ''
                        response_name = ''
                        expect(transaction.response.answer.size).to be 0

                        transaction.passthrough(resolver) do | reply |
                           response_object = reply
                        end
                        expect(response_object.answer.length).to be > 0
                end
		
		it "should fail the request" do
			transaction = RubyDNS::Transaction.new(server, query, question, IN::A, response)
			
			transaction.fail! :NXDomain
			
			expect(transaction.response.rcode).to be Resolv::DNS::RCode::NXDomain
		end
	end
end
