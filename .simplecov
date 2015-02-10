
SimpleCov.start do
	add_filter "/spec/"
end

# Work correctly across forks:
pid = Process.pid
SimpleCov.at_exit do
	SimpleCov.result.format! if Process.pid == pid
end

if ENV['TRAVIS']
	require 'coveralls'
	Coveralls.wear!
end
