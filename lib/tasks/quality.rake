# frozen_string_literal: true

namespace :quality do
  desc "Run crap4r (CRAP score: complexity x untested code)"
  task :crap do
    sh "bundle exec crap4r app/slices lib"
  end

  desc "Run mutant against slice domain code"
  task :mutant do
    sh "bundle exec mutant run"
  end

  desc "Run rubocop"
  task :rubocop do
    sh "bundle exec rubocop"
  end
end

desc "Full quality gate: specs, features, crap4r, mutation tests"
task quality: :environment do
  sh "bundle exec rspec"
  sh "bundle exec cucumber"
  Rake::Task["quality:crap"].invoke
  Rake::Task["quality:mutant"].invoke
end
