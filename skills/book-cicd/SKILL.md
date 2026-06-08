---
name: book-cicd
description: Use when setting up or modifying monorepo CI/CD and automation for the iOS book curation app and Cloudflare Worker, including GitHub Actions path-based workflows, Worker deployment, iOS simulator build/test, API contract fixtures, Firebase config validation, Crashlytics dSYM upload, and TestFlight strategy.
---

# Book Monorepo CI/CD

Use this skill for automation in the single repository containing iOS, Worker, and docs.

## CI/CD Strategy

- One monorepo, independent iOS and Worker workflows.
- Path-based CI.
- Worker deploys automatically on main.
- iOS auto-validates on PR/main, but TestFlight is manual or tag-based later.
- Firebase App Distribution is excluded.

## Security Rules

- Do not run production deploy jobs for pull requests from forks.
- Do not echo secrets, decoded plist contents, service-account JSON, provisioning profiles, or private keys in logs.
- Store deploy credentials only in GitHub Actions secrets or the target platform secret store.
- Keep generated credential files out of artifacts unless they are encrypted and required for a reviewed release process.

## Workflow Files

Recommended:

- `.github/workflows/ios-ci.yml`
- `.github/workflows/worker-ci.yml`
- `.github/workflows/worker-deploy.yml`
- `.github/workflows/docs-check.yml`

## Priority

1. Worker CI.
2. iOS simulator build/test CI.
3. Worker production deploy.
4. API fixture/DTO decode test.
5. Firebase config validation.
6. Crashlytics dSYM upload.
7. iOS TestFlight upload.

## References

Read `references/cicd.md` for branch strategy, path triggers, secrets, workflow examples, and success criteria.
