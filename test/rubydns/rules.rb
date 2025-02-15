#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2012-2020, by Samuel Williams.

require "rubydns"

describe RubyDNS::RuleBasedServer do
	IN = Resolv::DNS::Resource::IN

	true_callback = Proc.new { true }

	let(:server) {double(:logger => Console.logger)}

	it "should match string patterns correctly" do
		transaction = double(:query => Resolv::DNS::Message.new(0))

		rule = RubyDNS::RuleBasedServer::Rule.new(["foobar", IN::A], true_callback)

		expect(rule.call(server, "foobar", IN::A, transaction)).to be == true
		expect(rule.call(server, "barfoo", IN::A, transaction)).to be == false
		expect(rule.call(server, "foobar", IN::TXT, transaction)).to be == false
	end

	it "should match regular expression patterns correctly" do
		transaction = double(:query => Resolv::DNS::Message.new(0))

		rule = RubyDNS::RuleBasedServer::Rule.new([/foo/, IN::A], true_callback)

		expect(rule.call(server, "foobar", IN::A, transaction)).to be == true
		expect(rule.call(server, "barbaz", IN::A, transaction)).to be == false
		expect(rule.call(server, "foobar", IN::TXT, transaction)).to be == false
	end

	it "should match callback patterns correctly" do
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
