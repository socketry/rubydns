# Wikipedia DNS

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
