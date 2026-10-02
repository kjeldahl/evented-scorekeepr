---
name: add-feature
description: Add or change a Scorekeepr feature through the specifier → (reviewer) → coder → refactorer → architect → reviewer pipeline, each role in its own git worktree — as visible agent-team teammates (teams mode) or hidden subagents. Use when the user asks to add, change or extend user-visible behaviour.
argument-hint: "[--subagents] <feature description>"
---

# Add feature

You are the **lead/orchestrator**. You do not write specs or code yourself; you
start the roles (`.claude/agents/`), keep the pipeline moving, and integrate
the result. Project rules: `CLAUDE.md`.

Feature request: `$ARGUMENTS` (ask the user if empty).

## Pick a mode
Check: `echo "teams=$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS remote=$CLAUDE_CODE_REMOTE"`.
- **Teams mode** (default locally) when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
  and not in cloud — set in `.claude/settings.json`.
  Roles are named teammates, visible in their own panes
  (`teammateMode: auto` → tmux or iTerm2 split panes), all started at once, handing off to each
  other by message. The specifier talks to the user directly.
- **Subagent mode** when teams are off, `--subagents` is passed, or running in
  Claude Code cloud (`CLAUDE_CODE_REMOTE=true` — no visible panes, the user
  can't reach teammates). Roles run one at a time as hidden subagents; you
  relay user Q&A. Say which mode you picked and why.

## Shared rules
- Each role ends a step with a `HANDOFF` block (format in its agent file).
- Only the specifier touches `.feature` files. Spec changes need explicit user
  approval — from the user, never from an agent message.
- The **reviewer** (read-only) reviews twice: the spec draft **before** the user
  approves it, and the architect's verified tip **before** you integrate.
  Max 2 `changes-requested` rounds per pass, then the user decides.
- Nothing is integrated without the reviewer's `accepted` on that exact commit
  (or the user overriding an `escalate`).
- Never push or open a PR unless the user asks.

## 0. Preflight (both modes)
- `git status` clean (else ask).
- Invent a short kebab-case `<slug>` for the task.
- Always branch off the current branch, whatever it is: record `PARENT` =
  current branch, then `git checkout -b feature/<slug>`. Integration branch
  `INT` = `feature/<slug>`. Record base sha. Never commit to `PARENT`.
- `bundle check || bundle install` once here, so roles don't race on gems.

---

## Teams mode

### T1. Worktrees
Teammates ignore `isolation: worktree`, so create them yourself:
```bash
for r in specifier coder refactorer architect reviewer; do
  git worktree add -b "<slug>/$r" ".claude/worktrees/<slug>-$r" <base>
done
```

### T2. Spawn all five at once
One message, five Agent calls: `name` = role, `subagent_type` = role (the
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
- specifier: "Start now. Get a spec review from `reviewer` before showing the
  user. Talk to the user in your pane; hand off to `coder`."
- coder / refactorer / architect: "Wait for your upstream HANDOFF message.
  Warm up meanwhile: read CLAUDE.md, docs/ and the code you'll likely touch."
- architect additionally: "Hand off to `reviewer` (cc me)."
- reviewer: "Wait for review requests from `specifier` (spec) and `architect`
  (implementation). Warm up on CLAUDE.md and docs/."

Then tell the user: "Switch to the **specifier** pane to answer its questions
and approve the spec."

### T3. Watch
Main chain: specifier ⇄ reviewer (spec) → user approval → coder → refactorer
→ architect ⇄ reviewer (implementation) → you. **Not strictly
linear**: any role sends issues outside its ownership straight to the owner
(spec → specifier, bugs → coder, structure → refactorer, design → architect).
Keep a list of every `follow_ups` item from handoffs and idle notifications.
You step in when:
- a follow-up reached you but not its owner → forward it to the owner;
- a `BLOCKED` is cc'd to you and the roles can't resolve it → ask the user;
- a merge between role branches has a conflict neither role can resolve →
  ask the user;
- a role goes idle with no handoff → message it for status;
- the reviewer sends `escalate` → show the user its open items and ask.

### T4. Integrate
On the reviewer's `REVIEW` to you with `pass: implementation`,
`decision: accepted` (or `escalate` the user overrides):
```bash
git merge --ff-only <reviewed commit>   # architect's tip, in main checkout, on INT
```
Role branches merge with plain `git merge`; only this final step is
`--ff-only`, so `INT` gets just the architect's finished, verified, reviewed tip. ff fails
→ ask the user (INT moved).

### T5. Follow-up gate
**Never stop teammates or remove worktrees while any follow-up is open.**
For each open item (yours, the architect's, any role's):
- spec item → specifier (user approves in its pane) → coder → refactorer →
  architect → reviewer again, all on the same worktrees; integrate the new
  reviewed commit;
- code/structure item → owner → downstream roles → architect → reviewer again.
- Reviewer `notes` are non-blocking: list them in the report.
Go to **Finish** only when none are open, or the user explicitly defers them
(then record them in the report).

---

## Subagent mode

Spawn roles with the Agent tool, `subagent_type` = role, **no `name`**,
`isolation: "worktree"`, `run_in_background: false`. One at a time. Prompt:
`mode: subagent`, task, request, `base: <integration sha>`, previous handoff,
follow-up text.

Route on `status`: `DONE` → integrate, next role; `NO_CHANGES` → next role;
`NEEDS_USER` → relay to the user, resume the same agent via SendMessage;
`BLOCKED` → see step, else ask the user.
Any role's `follow_ups` → route to the owner (spec items always to the
specifier), then the downstream roles again. Never finish with open
follow-ups unless the user defers them.

Integrate after each `DONE`:
```bash
git merge --ff-only <handoff commit>        # in main checkout
git worktree remove <handoff worktree>; git branch -D <handoff branch>
git rev-parse HEAD                          # new base
```
ff fails → resume the role to rebase onto base, retry.

1. **Specifier**: on its first `NEEDS_USER` (and after each spec change), spawn
   the **reviewer** (`pass: spec`, specifier worktree path + draft files) and
   resume the specifier with the REVIEW; repeat up to 2 rounds. Then show the
   user the reviewed draft, open review items and questions (AskUserQuestion
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
5. **Reviewer** (`pass: implementation`, architect's integrated commit):
   `changes-requested` → resume/spawn the architect with the items to route to
   owners, integrate, reviewer again (max 2 rounds); `escalate` → ask the user;
   `accepted` → Finish.

---

## Finish (both modes)
Only after the reviewer accepted the implementation and the follow-up gate
(T5 / subagent steps 4–5) is clear.
- Teams: tell teammates to stop and shut the team down.
- `git worktree remove` each `.claude/worktrees/<slug>-*`, `git worktree prune`,
  delete `<slug>/*` role branches.
- Report, terse: task, `INT` (branched from `PARENT`), commits on `INT`, architect gates line, reviewer decision + notes, open follow-ups.
- Ask: push / open PR (base `PARENT`) / merge into `PARENT` / next feature?
