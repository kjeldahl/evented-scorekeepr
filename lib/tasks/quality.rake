# frozen_string_literal: true

namespace :quality do
  desc "Run crap4r (CRAP score: complexity x untested code)"
  task :crap do
    sh "bundle exec crap4r app/slices lib"
  end

  desc "Run mutant against slice domain code touched since SINCE (default origin/main)"
  task :mutant do
    since = ENV.fetch("SINCE", "origin/main")
    if system("git rev-parse -q --verify #{since}^{commit}", out: File::NULL, err: File::NULL)
      sh "bundle exec mutant run --since #{since}"
    else
      puts "Base revision #{since} not found; running the full mutation suite"
      Rake::Task["quality:mutant:full"].invoke
    end
  end

  namespace :mutant do
    desc "Run mutant against all slice domain code (the weekly CI job)"
    task :full do
      sh "bundle exec mutant run"
    end
  end

  desc "Run rubocop"
  task :rubocop do
    sh "bundle exec rubocop"
  end

  desc "Run packwerk (slice boundary check: no cross-slice constant refs)"
  task :packwerk do
    sh "bundle exec packwerk check"
  end
end

desc "Full quality gate: specs, features, crap4r, mutation tests"
task quality: :environment do
  sh "bundle exec rspec"
  sh "bundle exec cucumber"
  Rake::Task["quality:packwerk"].invoke
  Rake::Task["quality:crap"].invoke
  Rake::Task["quality:mutant"].invoke
end
