#!/usr/bin/env ruby

# build google force safe search ruls for rubyDNS 

google_domains = `curl https://www.google.com/supported_domains 2>> /dev/null | sed "s/^.//g"`.split("\n") 

google_domains.each do | dom | 

  puts ""
  puts "#match #{dom}"
  puts "match(/^#{dom}$/, IN::A) do |transaction|"
  puts "  transaction.respond!(Name.create('forcesafesearch.google.com'), resource_class: IN::CNAME)"
  puts "end"
  puts "match(/^www.#{dom}$/, IN::A) do |transaction|"
  puts "  transaction.respond!(Name.create('forcesafesearch.google.com'), resource_class: IN::CNAME)"
  puts "end"

end
