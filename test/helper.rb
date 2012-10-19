
$LOAD_PATH.unshift File.expand_path("../../lib/", __FILE__)

require 'rubygems'
require 'test/unit'
require 'resolv'

Name = Resolv::DNS::Name
IN = Resolv::DNS::Resource::IN
