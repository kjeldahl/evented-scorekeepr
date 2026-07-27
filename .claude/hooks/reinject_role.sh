#!/bin/bash
# Re-anchor a Swarm-Forge agent on its role + constitution AFTER a Claude Code compaction.
# Wired via a SessionStart hook (matcher "compact"). Whatever this prints to stdout is
# auto-injected into the freshly-compacted context as a system reminder.
set -u
ROLE="${SWARMFORGE_ROLE:-unknown}"

# The .swarmforge layout: role shims live at .swarmforge/prompts/<role>.md.
# They reference swarmforge/constitution.prompt and swarmforge/roles/<role>.prompt
# (relative to repo root). Those .prompt files may not exist if the agent gets
# its instructions from Claude Code's session prompt instead - so fall back
# to the .md shim itself.
FILE=""
for f in \
  ".swarmforge/constitution.prompt" \
  ".swarmforge/roles/${ROLE}.prompt" \
  ".swarmforge/prompts/${ROLE}.md"; do
  [ -f "$f" ] && { FILE="$f"; break; }
done

echo "── Post-compaction re-anchor ──"
echo "Your conversation history was just summarized. You are the '${ROLE}' agent."
echo "Re-read your constitution below and resume STRICTLY in-role and by the handoff protocol."
if [ -n "$FILE" ]; then
  echo
  echo "Constitution (${FILE}):"
  # Capped to keep post-compaction context lean; the agent can Read the full file if needed.
  sed -n '1,80p' "$FILE"
else
  echo "(constitution file not found for role '${ROLE}'; Read the .swarmforge/ docs to re-orient)"
fi
exit 0