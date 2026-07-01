---
name: project-workflow
description: Use for project work completion, verification and review agent handoff, local work logging, branch naming, commit message format, GitHub PR publish/merge workflow, main pull synchronization, and PR merge-order reporting across this repository.
---

# Project Workflow

Use this skill whenever completing implementation, documentation, CI, planning, or maintenance work in this repository.

## Completion Checklist

- Review the diff before finishing.
- Run the most relevant available verification for the change.
- When the user asks to finish or publish work, call separate verification and review subagents before committing.
- Separate unfinished follow-ups from completed implementation notes.
- Keep branch and commit units small enough to verify independently.

## Local Work Logs

- Write remaining improvements, follow-ups, and next-priority work in `.local/TODO.md`.
- Write completed and implemented work in `.local/WORK_LOG.md`.
- Keep `.local/WORK_LOG.md` in reverse chronological order, with the newest work at the top.
- Treat `.local/` as personal local workflow state, not shared project documentation.

## Branch Rules

- Use short-lived TBD-like branches.
- Prefer branch names like `Fix/[topic]`, `Feature/[topic]`, or `Docs/[topic]`.
- Do not use a `codex/` branch prefix in this repository.
- Keep one branch focused on one purpose.
- If work spans multiple branches, report the recommended PR merge order after all work is complete.

## Commit Rules

- Use commit messages like `feat: ...`, `fix: ...`, `refactor: ...`, `chore: ...`, or `docs: ...`.
- Split commits by meaningful, verifiable units.
- Commit only the files that belong to the current task.

## Finish And Publish Flow

Use this sequence when the user asks to complete work and publish it:

1. Inspect `git status --short --branch`, `git diff --name-only`, and `git diff --cached --name-only`.
2. Spawn two read-only subagents:
   - Verification agent: run the relevant project checks and report command results.
   - Review agent: review only the current task diff and report findings with file/line references.
3. Do not commit if either agent reports a blocking issue. Fix the issue, rerun the relevant checks, and repeat agent verification/review when the fix materially changes the diff.
4. Create or switch to a focused branch using this repository's branch rules.
5. Stage only task-owned files explicitly. Do not use broad staging when unrelated changes exist.
6. Commit with the appropriate conventional prefix.
7. Push the branch.
8. Create a PR targeting `main`.
9. Merge the PR only after creation succeeds and there are no blocking checks or review findings.
10. Check out `main` and run `git pull --ff-only origin main`.
11. End by reporting the branch, commit, PR URL/number, merge result, final `main` status, and verification/review results.

## GitHub Tool Preference

- Prefer the GitHub connector for PR creation and merge operations when it has permission.
- If the connector returns a permission error, use `gh` as fallback for PR creation or merge.
- Before using `gh`, run `gh auth status`. If the token is invalid but the requested `gh` command still succeeds through the user's local credential setup, continue and report the connector permission fallback.
- If both connector and `gh` fail, stop after the successful local git step and tell the user exactly which authentication or permission failed.
- Never assume `gh` is the only path. Try the connector first for GitHub write actions that it supports, then fall back to `gh` only when needed.
