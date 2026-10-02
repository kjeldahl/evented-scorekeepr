# frozen_string_literal: true

# SimpleCov for the RSpec and Cucumber suites. Required first from
# spec/spec_helper.rb and features/support/env.rb, before Rails loads.
# Both runs merge into one coverage/ result (command names "RSpec" and
# "Cucumber Features"). On CI it also writes coverage/coverage.json for
# script/coverage_report.rb (PR comment).
#
# Skipped when crap4r already started SimpleCov (it injects its own setup
# via RUBYOPT) and under mutant, where coverage is only overhead.
return if defined?(Mutant)

require "simplecov"
return if SimpleCov.running

require "simplecov-json"

SimpleCov.start do
  enable_coverage :branch
  merge_timeout 3600

  track_files "{app,lib}/**/*.rb"
  add_filter %r{\A/(spec|features|config|db|vendor|script|bin)/}

  %w[identity accounts leagues matches scoreboards statistics].each do |slice|
    add_group slice.capitalize, "app/slices/#{slice}/"
  end
  add_group "Root", %r{\A/(app/(?!slices/)|lib/)}

  if ENV["CI"]
    formatter SimpleCov::Formatter::MultiFormatter.new(
      [
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::JSONFormatter
      ]
    )
  end
end
