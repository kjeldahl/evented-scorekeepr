# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"
require "fileutils"
require "shellwords"

# --- Self-logging tool surface -------------------------------------------
# Every work/quality task tees its full output to a timestamped file under
# tmp/logs/ and prints "log: <path>" as its last stdout line. Callers add NO
# redirection/tee of their own - read/grep the logged file to inspect results.
LOG_DIR = "tmp/logs"

def log_path(name)
  FileUtils.mkdir_p(LOG_DIR)
  File.join(LOG_DIR, "#{name}-#{Time.now.strftime('%Y-%m-%dT%H:%M:%S')}.log")
end

# Run cmd, teeing combined stdout+stderr to console AND a per-task log.
# Prints "log: <path>" last. Returns [success?, log_path].
def run_logged(name, cmd)
  log = log_path(name)
  ok = system("bash", "-c", "set -o pipefail; { #{cmd}; } 2>&1 | tee #{Shellwords.escape(log)}")
  puts "log: #{log}"
  [ !!ok, log ]
end

# Like run_logged but aborts (like sh) when the command fails.
def sh_logged(name, cmd)
  ok, log = run_logged(name, cmd)
  abort("#{name} failed; see #{log}") unless ok
  log
end

# Parse mutant's coverage percentage out of a logged run.
def mutant_coverage(log)
  (m = File.read(log).match(/Coverage:\s+([0-9.]+)%/)) && m[1].to_f
end

# Gate on mutant coverage parsed from the log rather than exit status.
def assert_mutant_coverage(log, threshold)
  cov = mutant_coverage(log) or abort("could not parse mutant coverage; see #{log}")
  abort("mutant coverage #{cov}% below threshold #{threshold}%; see #{log}") if cov < threshold
  cov
end

Rails.application.load_tasks
