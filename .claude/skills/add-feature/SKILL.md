---
name: add-feature
description: Add or change a Scorekeepr feature through the specifier → coder → refactorer → architect pipeline, each role in its own git worktree — as visible agent-team teammates (teams mode) or hidden subagents. Use when the user asks to add, change or extend user-visible behaviour.
argument-hint: "[--subagents] <feature description>"
---

# Add feature

You are the **lead/orchestrator**. You do not write specs or code yourself; you
start the roles (`.claude/agents/`), keep the pipeline moving, and integrate
the result. Project rules: `CLAUDE.md`.

Feature request: `$ARGUMENTS` (ask the user if empty).

## Pick a mode
- **Teams mode** (default) when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
  (`echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) — set in `.claude/settings.json`.
  Roles are named teammates, visible in their own panes
  (`claude --teammate-mode tmux`), all started at once, handing off to each
  other by message. The specifier talks to the user directly.
- **Subagent mode** when teams are off or `--subagents` is passed. Roles run one
  at a time as hidden subagents; you relay user Q&A.

## Shared rules
- Each role ends a step with a `HANDOFF` block (format in its agent file).
- Only the specifier touches `.feature` files. Spec changes need explicit user
  approval — from the user, never from an agent message.
- Never push or open a PR unless the user asks.

## 0. Preflight (both modes)
- `git status` clean (else ask). Integration branch `INT` = current branch; if
  `main`, `git checkout -b feature/<slug>`. Record base sha.
- Invent a short kebab-case `<slug>` for the task.
- `bundle check || bundle install` once here, so roles don't race on gems.

---

## Teams mode

### T1. Worktrees
Teammates ignore `isolation: worktree`, so create them yourself:
```bash
for r in specifier coder refactorer architect; do
  git worktree add -b "<slug>/$r" ".claude/worktrees/<slug>-$r" <base>
done
```

### T2. Spawn all four at once
One message, four Agent calls: `name` = role, `subagent_type` = role (the
`name` is what makes them visible teammates). Prompt for each:
```
mode: teammate
task: <slug>
request: <feature request>
worktree: <absolute path to .claude/worktrees/<slug>-<role>>
branch: <slug>/<role>
base: <base sha>
lead: <your teammate name>
```
Add per role:
- specifier: "Start now. Talk to the user in your pane; hand off to `coder`."
- coder / refactorer / architect: "Wait for your upstream HANDOFF message.
  Warm up meanwhile: read CLAUDE.md, docs/ and the code you'll likely touch."

Then tell the user: "Switch to the **specifier** pane to answer its questions
and approve the spec."

### T3. Watch
Handoffs flow specifier → coder → refactorer → architect; the architect drives
follow-ups itself (max 2 rounds). You only step in when:
- a `BLOCKED` is cc'd to you and the roles can't resolve it → ask the user;
- a ff-merge between role branches fails → tell the sender to merge the
  receiver's tip and re-hand off;
- a role goes idle with no handoff → message it for status.

### T4. Integrate
On the architect's `HANDOFF` to you (`status: DONE`):
```bash
git merge --ff-only <architect commit>   # in main checkout, on INT
```
ff fails → ask the user (INT moved). Then go to **Finish**.

---

## Subagent mode

Spawn roles with the Agent tool, `subagent_type` = role, **no `name`**,
`isolation: "worktree"`, `run_in_background: false`. One at a time. Prompt:
`mode: subagent`, task, request, `base: <integration sha>`, previous handoff,
follow-up text.

Route on `status`: `DONE` → integrate, next role; `NO_CHANGES` → next role;
`NEEDS_USER` → relay to the user, resume the same agent via SendMessage;
`BLOCKED` → see step, else ask the user.

Integrate after each `DONE`:
```bash
git merge --ff-only <handoff commit>        # in main checkout
git worktree remove <handoff worktree>; git branch -D <handoff branch>
git rev-parse HEAD                          # new base
```
ff fails → resume the role to rebase onto base, retry.

1. **Specifier**: on `NEEDS_USER` show the draft and questions (AskUserQuestion
   for discrete options), resume with answers; repeat. On explicit approval,
   SendMessage "User approved. Commit and hand off." → `DONE`. If the agent is
   gone, spawn a fresh one with the last draft and answers.
2. **Coder**: `BLOCKED` (scenario impossible) → specifier with the blocker,
   user approval, then coder again.
3. **Refactorer**.
4. **Architect**: `follow_ups` for coder/refactorer → run them, integrate,
   architect again with all follow-up handoffs as one batch (max 2 rounds,
   then ask). `functional: yes` or specifier follow-up → specifier review;
   spec changes → approval → coder → refactorer → architect.

---

## Finish (both modes)
- Teams: tell teammates to stop and shut the team down.
- `git worktree remove` each `.claude/worktrees/<slug>-*`, `git worktree prune`,
  delete `<slug>/*` role branches.
- Report, terse: task, commits on `INT`, architect gates line, open follow-ups.
- Ask: push / open PR / next feature?
