# frozen_string_literal: true

# All tasks self-log via the shared Rakefile helpers (run_logged/sh_logged):
# each tees full output to tmp/logs/<name>-<ISO8601>.log and prints
# "log: <path>" last. Never wrap these in shell redirection or tee - grep the
# logged file to inspect results, and never re-run a task just to read a number.

namespace :quality do
  desc "Run rspec"
  task :spec do
    sh_logged("spec", "bundle exec rspec")
  end

  desc "Run cucumber (Gherkin acceptance)"
  task :features do
    sh_logged("features", "bundle exec cucumber")
  end

  desc "Run crap4r (CRAP score: complexity x untested code)"
  task :crap do
    sh_logged("crap", "bundle exec crap4r app/slices lib")
  end

  desc "Run mutant against slice domain code touched since SINCE (default origin/main)"
  task :mutant do
    since = ENV.fetch("SINCE", "origin/main")
    if system("git rev-parse -q --verify #{since}^{commit}", out: File::NULL, err: File::NULL)
      log = sh_logged("mutant", "bundle exec mutant run --since #{since}")
      assert_mutant_coverage(log, 100.0)
    else
      puts "Base revision #{since} not found; running the full mutation suite"
      Rake::Task["quality:mutant:full"].invoke
    end
  end

  namespace :mutant do
    desc "Run mutant against all slice domain code (the weekly CI job)"
    task :full do
      log = sh_logged("mutant-full", "bundle exec mutant run")
      assert_mutant_coverage(log, 100.0)
    end
  end

  desc "Run rubocop"
  task :rubocop do
    sh_logged("rubocop", "bundle exec rubocop")
  end

  desc "Run packwerk (slice boundary check: no cross-slice constant refs)"
  task :packwerk do
    sh_logged("packwerk", "bundle exec packwerk check")
  end
end

desc "Full quality gate: specs, features, crap4r, mutation tests"
task quality: :environment do
  Rake::Task["quality:spec"].invoke
  Rake::Task["quality:features"].invoke
  Rake::Task["quality:packwerk"].invoke
  Rake::Task["quality:crap"].invoke
  Rake::Task["quality:mutant"].invoke
end
