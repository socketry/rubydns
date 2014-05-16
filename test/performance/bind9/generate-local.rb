#!/usr/bin/env ruby

File.open("local.zone", "w") do |f|
	f.write(DATA.read)
	
	(1..5_000).each do |i|
		f.puts "domain#{i} IN A #{69}.#{(i >> 16)%256}.#{(i >> 8)%256}.#{i%256}"
	end
end

__END__
;
; BIND data file for local loopback interface
;
$TTL    604800
@       IN      SOA     ns.local. postmaster.localhost (
                      2         ; Serial
                 604800         ; Refresh
                  86400         ; Retry
                2419200         ; Expire
                 604800 )       ; Negative Cache TTL
;
local.            IN	NS	ns.local.
ns.local.         IN	A	127.0.0.1

