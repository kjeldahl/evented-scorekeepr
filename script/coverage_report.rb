#!/usr/bin/env ruby
# frozen_string_literal: true

# Summarises SimpleCov JSON (simplecov-json) per slice, per other app/
# subfolder and lib, as markdown for the PR comment, plus a collapsed file
# list. With a base report it adds deltas and lists only the files whose
# coverage changed; without one (first run) it lists every file.
#
# Usage:
#   ruby script/coverage_report.rb <pr_coverage.json>
#   ruby script/coverage_report.rb <base_coverage.json> <pr_coverage.json>

require "json"

def load_coverage(path)
  data = JSON.parse(File.read(path))
  result = data.fetch("result", data)
  metrics = result.fetch("metrics", {})

  file_coverage = {}
  result.fetch("files", []).each do |file|
    lines = file.dig("coverage", "lines") || file["coverage"]
    next unless lines.is_a?(Array)

    relevant = lines.compact
    short_path = file["filename"].sub(%r{\A.*?/(?=(app|lib)/)}, "")
    file_coverage[short_path] = { covered: relevant.count(&:positive?), total: relevant.size }
  end

  {
    line_percent: metrics.fetch("covered_percent", 0).round(2),
    covered_lines: metrics.fetch("covered_lines", 0),
    total_lines: metrics.fetch("total_lines", 0),
    files: file_coverage,
    groups: group_totals(file_coverage)
  }
end

def group_for(path)
  case path
  when %r{\Aapp/slices/([^/]+)/} then Regexp.last_match(1)
  when %r{\A(app/[^/]+)/} then Regexp.last_match(1)
  when %r{\Alib/} then "lib"
  else "other"
  end
end

# Slices, then other app/ subfolders, lib, other; alphabetical within each.
def group_order(name)
  rank = if name.start_with?("app/") then 0
  elsif name == "lib" then 1
  elsif name == "other" then 2
  else -1
  end
  [ rank, name ]
end

def group_totals(files)
  totals = Hash.new { |h, k| h[k] = { covered: 0, total: 0 } }
  files.each do |path, data|
    totals[group_for(path)][:covered] += data[:covered]
    totals[group_for(path)][:total] += data[:total]
  end
  totals.sort_by { |name, _| group_order(name) }.to_h
end

def percent(data)
  return nil unless data
  return 100.0 if data[:total].zero?

  (data[:covered].to_f / data[:total] * 100).round(2)
end

def format_percent(data)
  pct = percent(data)
  pct ? "#{pct}%" : "—"
end

def format_lines(data)
  data ? "#{data[:covered]}/#{data[:total]}" : "—"
end

def format_delta(delta)
  sign = delta >= 0 ? "+" : ""
  "#{sign}#{delta.round(2)}%"
end

def delta_cell(base, pr)
  return "—" unless base && pr

  delta = percent(pr) - percent(base)
  icon = if delta > 0.5 then " ⬆"
  elsif delta < -0.5 then " ⬇"
  else ""
  end
  "#{format_delta(delta)}#{icon}"
end

def label(name)
  name.start_with?("app/") || [ "lib", "other" ].include?(name) ? "`#{name}`" : name
end

if ARGV.length == 1
  pr = load_coverage(ARGV[0])

  puts "## Coverage Report"
  puts ""
  puts "**Overall: #{pr[:line_percent]}%** (#{pr[:covered_lines]}/#{pr[:total_lines]} lines)"
  puts ""
  puts "| Slice | Coverage | Lines |"
  puts "|-------|----------|-------|"
  pr[:groups].each do |name, data|
    puts "| #{label(name)} | #{format_percent(data)} | #{format_lines(data)} |"
  end
  puts ""
  puts "<details><summary>#{pr[:files].size} file(s)</summary>"
  puts ""
  puts "| File | Coverage | Lines |"
  puts "|------|----------|-------|"
  pr[:files].sort.each do |path, data|
    puts "| `#{path}` | #{format_percent(data)} | #{format_lines(data)} |"
  end
  puts ""
  puts "</details>"

  exit 0
end

if ARGV.length != 2
  warn "Usage: ruby script/coverage_report.rb [base_coverage.json] <pr_coverage.json>"
  exit 1
end

base = load_coverage(ARGV[0])
pr = load_coverage(ARGV[1])

overall_delta = pr[:line_percent] - base[:line_percent]

puts "## Coverage Change Report"
puts ""
puts "**Overall: #{pr[:line_percent]}%** (#{pr[:covered_lines]}/#{pr[:total_lines]} lines), " \
     "#{format_delta(overall_delta)} vs base (#{base[:line_percent]}%)"
puts ""
puts "| Slice | Base | PR | Delta | Lines |"
puts "|-------|------|----|-------|-------|"
groups = (base[:groups].keys | pr[:groups].keys).sort_by { |name| group_order(name) }
groups.each do |name|
  b = base[:groups][name]
  p = pr[:groups][name]
  puts "| #{label(name)} | #{format_percent(b)} | #{format_percent(p)} | #{delta_cell(b, p)} | #{format_lines(p)} |"
end
puts ""

changed_files = (base[:files].keys | pr[:files].keys).sort.reject do |path|
  b = base[:files][path]
  p = pr[:files][path]
  b && p && (percent(p) - percent(b)).abs <= 0.01
end

if changed_files.empty?
  puts "No per-file coverage changes."
else
  puts "<details><summary>#{changed_files.size} file(s) with coverage changes</summary>"
  puts ""
  puts "| File | Base | PR | Delta |"
  puts "|------|------|----|-------|"
  changed_files.each do |path|
    b = base[:files][path]
    p = pr[:files][path]
    status = if b.nil? then " (new)"
    elsif p.nil? then " (removed)"
    else ""
    end
    puts "| `#{path}`#{status} | #{format_percent(b)} | #{format_percent(p)} | #{delta_cell(b, p)} |"
  end
  puts ""
  puts "</details>"
end

# Exit with non-zero if coverage dropped significantly
if overall_delta < -1.0
  warn "\nWarning: Overall coverage dropped by #{format_delta(overall_delta)}"
  exit 1
end
