---
name: add-feature
description: Add or change a Scorekeepr feature through the specifier → coder → refactorer → architect pipeline, each role a subagent in its own git worktree. Use when the user asks to add, change or extend user-visible behaviour.
argument-hint: <feature description>
---

# Add feature

You are the **orchestrator**. You do not write specs or code yourself; you run
the role subagents (`.claude/agents/`), relay between them and the user, and
integrate their commits. Project rules: `CLAUDE.md`.

Feature request: `$ARGUMENTS` (ask the user if empty).

## Ground rules
- Spawn roles with the Agent tool, `subagent_type` = role name,
  `isolation: "worktree"`, `run_in_background: false`. One role at a time.
- Every role prompt includes: task name (once known), the feature request,
  `base: <integration sha>`, the previous role's handoff block, and any
  follow-up text.
- Each role ends with a `HANDOFF` block (format in its agent file). Route on
  `status`:
  - `DONE` → integrate, next role.
  - `NO_CHANGES` → skip integration, next role.
  - `NEEDS_USER` → relay to user, resume the same agent (SendMessage) with answers.
  - `BLOCKED` → see the role's step; otherwise show blocker to user and ask.
- Only the specifier touches `.feature` files. Any spec change needs explicit
  user approval.
- Never push or open a PR unless the user asks.

## Integration (after each `DONE`)
Integration branch = current branch of the main checkout (`INT`). If `INT` is
`main`, first `git checkout -b feature/<slug>`.
```bash
git merge --ff-only <handoff commit>        # in main checkout
git worktree remove <handoff worktree>
git branch -D <handoff branch>
git rev-parse HEAD                          # new base for next role
```
ff fails → the role didn't start from base; resume it to rebase onto base, retry.

## 0. Preflight
- `git status` clean (else ask user). Record `INT` and base sha.

## 1. Specify (specifier)
1. Spawn specifier with the request and base.
2. On `NEEDS_USER`: show the user the draft Gherkin and the questions (use
   AskUserQuestion when questions have discrete options). Resume the specifier
   via SendMessage with answers. Repeat.
3. When the user explicitly approves, SendMessage: "User approved. Commit and
   hand off." Expect `DONE` with `task:`. Integrate.
4. If the agent/worktree is gone before approval, spawn a fresh specifier with
   the last draft and answers.

## 2. Code (coder)
- Spawn coder. `DONE` → integrate.
- `BLOCKED` (scenario impossible) → spawn specifier with the blocker, back to
  step 1.2 (user approval required), then rerun coder.

## 3. Refactor (refactorer)
- Spawn refactorer. `DONE` → integrate.

## 4. Architect (architect)
- Spawn architect. `DONE` → integrate.
- `follow_ups` for coder/refactorer → run those roles (base = new sha, include
  the follow-up text), integrate, then architect again with all follow-up
  handoffs as one batch. Max 2 rounds; then ask the user.
- `follow_ups` for specifier, or `functional: yes` → spawn specifier in review
  mode with the architect's commits; any proposed `.feature` change goes
  through user approval (step 1.2) and then coder → refactorer → architect again.

## 5. Finish
- `git worktree prune`; delete leftover role branches from this run.
- Report to user, terse: task name, commits on `INT`, gates line from the
  architect, open follow-ups.
- Ask: push / open PR / next feature?
