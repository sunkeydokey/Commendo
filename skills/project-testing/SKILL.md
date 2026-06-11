---
name: project-testing
description: Use when selecting, running, or reporting verification for changes in the Commendo repository, especially iOS builds, Swift unit tests, UI tests, Worker checks, and Simulator-related validation. Enforces change-based test scope so UI tests run only when CommendoUITests files are added or modified, and prohibits direct Simulator operation through Computer Use.
---

# Project Testing

Use the smallest verification set justified by the current diff. Also follow `skills/project-workflow/SKILL.md` when completing work.

## Determine Changed Areas

Inspect both tracked and untracked files before choosing commands:

```text
git status --short
git diff --name-only
git diff --cached --name-only
git ls-files --others --exclude-standard
```

Treat a file as changed when it is added, modified, renamed, or deleted in the current worktree or index.

## iOS Verification

For production Swift changes under `Commendo/`:

1. Run a generic iOS Simulator build.
2. Run Swift unit tests only when behavior changed or `CommendoTests/` changed.
3. Restrict test execution to the unit-test target with `-only-testing:CommendoTests`.

Do not use an unrestricted `xcodebuild test` command because the scheme may include UI tests.

### UI Test Gate

Run UI tests only when at least one UI-test source file under `CommendoUITests/` was added or modified by the current task.

- If `CommendoUITests/` is unchanged: do not build-for-testing specifically for UI tests, do not run the UI-test target, and do not launch the app for manual UI verification.
- If UI-test files were only deleted: do not run UI tests.
- If qualifying UI-test files were added or modified: run only the relevant UI tests with `-only-testing:CommendoUITests` or a narrower test identifier.
- Production UI changes alone do not justify running UI tests.
- Existing unrelated UI-test changes in a dirty worktree do not justify running them unless they belong to the current task.

## Simulator Rules

- Never use Computer Use to open, inspect, click, type, scroll, or capture the Simulator.
- Never use `simctl boot`, `simctl install`, or `simctl launch` for routine verification.
- Let `xcodebuild` manage the selected Simulator when unit or approved UI tests require one.
- Do not substitute manual Simulator inspection for automated build or test verification.
- If visual verification is requested explicitly, report that it requires a separate user-driven check unless another non-Computer-Use workflow is provided.

## Worker Verification

For changes under `worker/`, run only checks relevant to the changed code, such as TypeScript checking, focused tests, or Wrangler dry-run validation. Do not run iOS tests unless shared contracts or iOS files also changed.

## Reporting

State exactly which checks ran and their results. Explicitly say UI tests were skipped because `CommendoUITests/` was unchanged when reporting iOS verification. Report blocked checks without replacing them with Simulator interaction.
