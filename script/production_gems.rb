#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints the gem set the production image installs at a commit: Gemfile
# dependencies outside the development/test/deploy groups (the Dockerfile's
# BUNDLE_WITHOUT) with their Gemfile options (require:, groups, platforms
# change what Bundler.require loads), expanded through Gemfile.lock to one
# "name-version source" line per spec, plus the bundler version. The deploy
# workflow compares it between the live version and the new commit, so
# Gemfile changes that only touch dev/test gems don't deploy. Parses only;
# installs and fetches nothing.
#
# Usage: ruby script/production_gems.rb <commit>

require "bundler"
require "tmpdir"

EXCLUDED_GROUPS = %i[development test deploy].freeze

commit = ARGV.fetch(0)

Dir.mktmpdir do |dir|
  %w[Gemfile Gemfile.lock].each do |file|
    File.write(File.join(dir, file), IO.popen([ "git", "show", "#{commit}:#{file}" ], &:read))
    abort "#{file} missing at #{commit}" unless $?.success?
  end

  dsl = Bundler::Dsl.new
  dsl.eval_gemfile(File.join(dir, "Gemfile"))
  lockfile = Bundler::LockfileParser.new(File.read(File.join(dir, "Gemfile.lock")))
  specs = lockfile.specs.group_by(&:name)

  direct = dsl.dependencies.reject { |dep| (dep.groups - EXCLUDED_GROUPS).empty? }
  pending = direct.map(&:name)
  seen = {}
  until pending.empty?
    name = pending.shift
    next if seen[name]

    seen[name] = specs.fetch(name, []).each do |spec|
      pending.concat(spec.dependencies.map(&:name))
    end
  end

  gemfile = direct.map do |dep|
    "gem #{dep.name} #{dep.requirement} require=#{dep.autorequire.inspect} " \
      "groups=#{dep.groups.sort.inspect} platforms=#{dep.platforms.sort.inspect}"
  end
  locked = seen.values.flatten.map { |spec| "#{spec.full_name} #{spec.source}" }
  puts gemfile.sort, locked.sort, "bundler #{lockfile.bundler_version}"
end
