---
name: project-workflow
description: Use for project work completion, local work logging, branch naming, commit message format, and PR merge-order reporting across this repository.
---

# Project Workflow

Use this skill whenever completing implementation, documentation, CI, planning, or maintenance work in this repository.

## Completion Checklist

- Review the diff before finishing.
- Run the most relevant available verification for the change.
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
- Keep one branch focused on one purpose.
- If work spans multiple branches, report the recommended PR merge order after all work is complete.

## Commit Rules

- Use commit messages like `feat: ...`, `fix: ...`, `refactor: ...`, `chore: ...`, or `docs: ...`.
- Split commits by meaningful, verifiable units.
- Commit only the files that belong to the current task.
