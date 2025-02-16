#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2012-2025, by Samuel Williams.

require "rubydns"

IN = Resolv::DNS::Resource::IN

describe RubyDNS::Rule do
	let(:server) {RubyDNS::Server.new}
	let(:query) {Resolv::DNS::Message.new(0)}
	let(:transaction) {Async::DNS::Transaction.new(server, query, nil, nil, nil)}
	
	it "should match string patterns correctly" do
		rule = subject.for(["foobar", IN::A]) {true}
		
		expect(rule.call(server, "foobar", IN::A, transaction)).to be == true
		expect(rule.call(server, "barfoo", IN::A, transaction)).to be == false
		expect(rule.call(server, "foobar", IN::TXT, transaction)).to be == false
	end
	
	it "should match regular expression patterns correctly" do
		rule = subject.for([/foo/, IN::A]) {true}
		
		expect(rule.call(server, "foobar", IN::A, transaction)).to be == true
		expect(rule.call(server, "barbaz", IN::A, transaction)).to be == false
		expect(rule.call(server, "foobar", IN::TXT, transaction)).to be == false
	end
	
	it "should match callback patterns correctly" do
		calls = 0
		
		callback = Proc.new do |name, resource_class|
			# A counter used to check the number of times this block was invoked.
			calls += 1
			
			name.size == 6
		end
		
		rule = RubyDNS::Rule.for([callback]) {true}
		
		expect(rule.call(server, "foobar", IN::A, transaction)).to be == true
		expect(rule.call(server, "foobarbaz", IN::A, transaction)).to be == false
		
		expect(calls).to be == 2
	end
end
