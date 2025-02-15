# frozen_string_literal: true
source "https://rubygems.org"

gemspec

group :maintenance, optional: true do
	gem "bake-modernize"
end

group :development do
	gem "process-daemon"
	gem "nio4r"
end

group :test do
	gem "sus"
	gem "covered"
	gem "decode"
	gem "rubocop"
end
