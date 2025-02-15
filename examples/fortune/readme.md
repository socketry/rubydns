# Fortune DNS

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
