#!/bin/bash
# Re-anchor a Swarm-Forge agent on its role constitution AFTER a Claude Code compaction.
# Registered via SessionStart(matcher:compact); stdout is injected as a system reminder.
#
# FIX 2026-07-29: read from 'swarmforge/' (NOT '.swarmforge/') and inject the role-specific
# scope file, not the constitution.prompt pointer. The old paths hit "not found" 100% of the
# time, so agents re-anchored on their role name but not their scope. '.swarmforge/' is
# gitignored runtime state (generated handoffs); the constitution is committed at 'swarmforge/'.
set -u
ROLE="${SWARMFORGE_ROLE:-unknown}"
BASE="${CLAUDE_PROJECT_DIR:-.}/swarmforge"          # 'swarmforge' — no leading dot

echo "── Post-compaction re-anchor ──"
echo "Your conversation history was just summarized. You are the '${ROLE}' agent."
echo "Re-read your constitution below and resume STRICTLY in-role and by the handoff protocol."

# shared rules (constitution.prompt is only a pointer; the real shared rules are the articles)
SHARED="$BASE/constitution/articles/project.prompt"
[ -f "$SHARED" ] && { echo; echo "── Shared constitution ($SHARED) ──"; cat "$SHARED"; }

# role-specific SCOPE — the part that defines what this role may and may NOT do
RF="$BASE/roles/${ROLE}.prompt"
if [ -f "$RF" ]; then
  echo; echo "── Your role: ${ROLE} ($RF) ──"; cat "$RF"
else
  echo; echo "(no role file at $RF — Read $BASE/ to re-orient)"
fi
exit 0
