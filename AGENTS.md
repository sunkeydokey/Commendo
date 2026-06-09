# AGENTS.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```text
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Completion, Logs, and Git Workflow

Before work:
- State assumptions, scope, and success criteria.
- Use the smallest branch and change unit that can be verified independently.

After work:
- Review the diff and run the most relevant available verification.
- Write remaining improvements and next-priority work in `.local/TODO.md`.
- Write completed and implemented work in `.local/WORK_LOG.md`.
- Keep `.local/WORK_LOG.md` in reverse chronological order, with the newest work at the top.

Git workflow:
- Use a TBD-like personal workflow: short-lived branches, small commits, and fast integration.
- Prefer branch names like `Fix/[topic]`, `Feature/[topic]`, or `Docs/[topic]`.
- Do not use a `codex/` branch prefix in this repository.
- Keep one branch focused on one purpose.
- Use commit messages like `feat: ...`, `fix: ...`, `refactor: ...`, `chore: ...`, or `docs: ...`.
- Split commits by meaningful, verifiable units.
- If work spans multiple branches, report the recommended PR merge order after all work is complete.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
