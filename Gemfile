source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "puma", ">= 5.0"

# Event sourcing via Dynamic Consistency Boundary event store
gem "dcb_event_store", github: "Kjeldahl/ruby-dcb"
gem "pg", "~> 1.5"
gem "connection_pool", "~> 2.4"

gem "bcrypt", "~> 3.1.7"

gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false

  # Quality gate: slice boundary enforcement (no cross-slice constant refs)
  gem "packwerk", require: false
  # packwerk requires benchmark, no longer a default gem on Ruby >= 4.0
  gem "benchmark", require: false

  gem "rspec-rails", "~> 8.0"
  gem "cucumber-rails", require: false
  gem "capybara"

  # Quality gates: mutation testing and CRAP score
  gem "mutant-rspec", "~> 0.13"
  gem "crap4r", github: "Kjeldahl/crap4r"
  gem "simplecov", require: false
  gem "simplecov-json", require: false
end

group :development do
  gem "web-console"
end
