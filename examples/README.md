# RubyDNS Examples

This directory contains several examples of customized RubyDNS servers,
intended to demonstrate how RubyDNS can be easily customized to specific
needs.

## FlakeyDNS (flakey-dns.rb)

A DNS server that selectively drops queries based on the requested domain name.  Queries for domains that match specified regular expressions (like 'microsoft.com' or 'sco.com') return NXDomain, while all other queries are passed to upstream resolvers.

By default this server will listen for UDP requests on port 5300 and does not need to be started as root.

To start the server, ensure that you're in the examples subdirectory and type

    bundle
    bundle exec ./flakey-dns.rb start

To see it in action you can then query some domains.  For example,

    dig @localhost -p 5300 slashdot.org -t A
    dig @localhost -p 5300 www.hackernews.com -t A

give the correct results. But

    dig @localhost -p 5300 microsoft.com -t A
    dig @localhost -p 5300 www.microsoft.com -t A
    dig @localhost -p 5300 www.microsoft.com

all give an NXDomain result.

## FortuneDNS (fortune-dns.rb)

A DNS server that allows a client to generate fortunes and fetch them with subsequent requests.  The server
'remembers' the fortunes it generates, and can serve them to future requests. The reason for this is because most fortunes won't fit over UDP (maximum size 512 bytes) and the client will request the same fortune via TCP.

You will need to have the `fortune` app installed on your system.  It comes installed by default on
most Linux distributions, and can be installed on a Mac with Homebrew by typing:

    # Homebrew
    brew install fortune
    # MacPorts
    sudo port install fortune
    # Arch Linux
    sudo pacman -S fortune-mod

By default this server will listen for UDP and TCP requests on port 53, and needs to be started as root.  It
assumes the existence of a user 'daemon', as whom the process will run.  If such a user doesn't exist on your
system, you will need to either create such a user or update the script to use a user that exists on your
system.

To start the server, ensure that you're in the examples subdirectory and type

    bundle
    sudo bundle exec ./fortune-dns.rb start

To create a new fortune type

    dig @localhost fortune -t TXT

This will result in an DNS answer that looks something like this:

    fortune.    0 IN  TXT "Text Size: 714 Byte Size: 714"
    fortune.    0 IN  CNAME 32bf3bf2b0a2255f2df00ed9e95c8185.fortune.

Take the CNAME from this result and query it.  For our example this would be:

    dig @localhost 32bf3bf2b0a2255f2df00ed9e95c8185.fortune -t TXT

And your answer will be a fortune.

You can also generate a 'short' fortune by typing the following:

    dig @localhost short.fortune -t TXT

or view the fortune stats with:

    dig @localhost stats.fortune -t TXT

## GeoIPDNS (geoip-dns.rb)

A sample DNS daemon that demonstrates how to use RubyDNS to build responses
that vary based on the geolocation of the requesting peer.  Clients of this
server who request A records will get an answer IP address based on the 
continent of the client IP address.

Please note that use of this example requires that the peer have a public
IP address.  IP addresses on private networks or the localhost IP (127.0.0.1)
cannot be resolved to a location, and so will always yield the unknown result.

This daemon requires the file downloaded from
[MaxMind](http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz)
For more information on the GeoIP library, please click [here](http://www.maxmind.com/en/geolite)
or [here](https://github.com/cjheath/geoip).  This file should be unzipped and placed in the
examples root directory, i.e. `examples/GeoLiteCountry.dat`.

By default this server will listen for UDP requests on port 5300 and does not need to be started as root.

To start the server, ensure that you're in the examples subdirectory and type

    bundle
    sudo bundle exec ./geoip-dns.rb start

To see the behavior, run a DNS query against the server where you are running the GeoIPDNS
daemon.  Depending on the continent to which the client machine's IP address is mapped,
you will receive a different IP address in the answer section:

    Africa - 1.1.1.1
    Antarctica - 1.1.2.1
    Asia - 1.1.3.1
    Europe - 1.1.4.1
    North America - 1.1.5.1
    Oceania - 1.1.6.1
    South America - 1.1.7.1

## WikipediaDNS (wikipedia-dns.rb)

A DNS server that queries Wikipedia and returns summaries for specifically crafted queries.

By default this server will listen for UDP and TCP requests on port 53, and needs to be started as root.  It
assumes the existence of a user 'daemon', as whom the process will run.  If such a user doesn't exist on your
system, you will need to either create such a user or update the script to use a user that exists on your
system.

To start the server, ensure that you're in the examples subdirectory and type

    bundle
    sudo bundle exec ./wikipedia-dns.rb start

To query Wikipedia, pick a term - say, 'helium' - and make a DNS query like

    dig @localhost helium.wikipedia -t TXT

The answer section should contain the summary for this topic from Wikipedia

    helium.wikipedia. 86400 IN  TXT "Helium is a chemical element with symbol He and atomic number 2. It is a colorless, odorless, tasteless, non-toxic, inert, monatomic gas that heads the noble gas group in the periodic table. Its boiling and melting points are the lowest among the elements" " and it exists only as a gas except in extreme conditions."

Long blocks of text cannot be easily replied in DNS as they must be chunked into segments at most 255 bytes. Long replies must be sent back using TCP.
