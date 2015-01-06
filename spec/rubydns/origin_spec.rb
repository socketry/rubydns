#!/usr/bin/env rspec

# Copyright, 2014, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

module RubyDNS::OriginSpec
	describe RubyDNS::Resolver do
		it "should generate fully qualified domain name with specified origin" do
			resolver = RubyDNS::Resolver.new([], origin: "foo.bar.")
			
			fully_qualified_name = resolver.fully_qualified_name("baz")
			
			expect(fully_qualified_name).to be_absolute
			expect(fully_qualified_name.to_s).to be == "baz.foo.bar."
		end
	end
	
	describe Resolv::DNS::Name do
		let(:name) {Resolv::DNS::Name.create("foo.bar")}
		
		it "should be relative" do
			expect(name).to_not be_absolute
			expect(name.to_s).to be == "foo.bar"
		end
		
		it "should add the specified origin" do
			fully_qualified_name = name.with_origin("org")
			
			expect(fully_qualified_name.to_a.size).to be 3
			expect(fully_qualified_name).to be_absolute
			expect(fully_qualified_name.to_s).to be == "foo.bar.org."
		end
		
		it "should handle nil origin as absolute" do
			fully_qualified_name = name.with_origin(nil)
			
			expect(fully_qualified_name.to_a.size).to be 2
			expect(fully_qualified_name).to be_absolute
			expect(fully_qualified_name.to_s).to be == "foo.bar."
		end
		
		it "should handle empty origin as absolute" do
			fully_qualified_name = name.with_origin('')
			
			expect(fully_qualified_name.to_a.size).to be 2
			expect(fully_qualified_name).to be_absolute
			expect(fully_qualified_name.to_s).to be == "foo.bar."
		end
	end
	
	describe Resolv::DNS::Name do
		let(:name) {Resolv::DNS::Name.create("foo.bar.")}
		
		it "should be absolute" do
			expect(name).to be_absolute
			expect(name.to_s).to be == "foo.bar."
		end
		
		it "should remove the specified origin" do
			relative_name = name.without_origin("bar")
			
			expect(relative_name.to_a.size).to be 1
			expect(relative_name).to_not be_absolute
			expect(relative_name.to_s).to be == "foo"
		end
		
		it "should not remove nil origin but become relative" do
			relative_name = name.without_origin(nil)
			
			expect(relative_name.to_a.size).to be 2
			expect(relative_name).to_not be_absolute
			expect(relative_name.to_s).to be == "foo.bar"
		end
		
		it "should not remove empty string origin but become relative" do
			relative_name = name.without_origin('')
			
			expect(relative_name.to_a.size).to be 2
			expect(relative_name).to_not be_absolute
			expect(relative_name.to_s).to be == "foo.bar"
		end
		
		it "should not raise an exception when origin isn't valid" do
			expect{name.without_origin('bob')}.to raise_exception(Resolv::DNS::OriginError)
		end
	end
end
