#!/bin/bash
# Cloud (Claude Code on the web) setup: prebuilt Ruby from .ruby-version via mise + gems.
# Idempotent; container state is cached after the first successful run.
# Network allowlist needed: mise-versions.jdx.dev, tuf-repo-cdn.sigstore.dev
# (github.com release downloads, registry.npmjs.org and rubygems.org already pass).
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

RUBY_VERSION_WANTED="$(sed 's/^ruby-//' .ruby-version | tr -d '[:space:]')"
export MISE_YES=1 MISE_RUBY_COMPILE=false   # prebuilt only (jdx/ruby, attested)

# pg gem needs libpq headers.
if ! dpkg -s libpq-dev >/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y -qq libpq-dev >/dev/null
fi

# mise itself comes from npm (mise.run / mise.jdx.dev are not reachable).
command -v mise >/dev/null 2>&1 || npm install -g --silent --no-fund --no-audit @jdxcode/mise
mise trust --quiet "$PWD/mise.toml" >/dev/null 2>&1 || true

if ! mise install "ruby@$RUBY_VERSION_WANTED"; then
  echo "session-start: could not install prebuilt Ruby $RUBY_VERSION_WANTED via mise" \
       "(check the network allowlist above). Skipping gem install." >&2
  exit 0
fi
RUBY_BIN="$(mise where "ruby@$RUBY_VERSION_WANTED")/bin"
export PATH="$RUBY_BIN:$PATH"

# Gems go into the mise Ruby (not vendor/) so role worktrees share them.
# Skip groups not needed for dev work: web-console, appsignal.
export BUNDLE_WITHOUT="development:production"
gem list -i bundler >/dev/null 2>&1 || gem install -N bundler
bundle install --jobs "$(nproc)" --retry 3

# Persist for the session: mise Ruby first, so /usr/local/bin/ruby (3.3) is shadowed.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PATH=\"$RUBY_BIN:\$PATH\""
    echo "export BUNDLE_WITHOUT=\"$BUNDLE_WITHOUT\""
  } >> "$CLAUDE_ENV_FILE"
fi
