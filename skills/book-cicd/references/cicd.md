# CI/CD Reference

## Repo

```text
BookCurationApp/
├─ iOS/
├─ worker/
├─ docs/
└─ .github/workflows/
```

## Branch Rules

- `main` is protected.
- PR required.
- Required CI must pass.
- Worker production deploy on main merge.
- iOS TestFlight later via tag or manual workflow.
- Production deploy workflows must not run for pull requests from forks.

## Path Triggers

iOS CI:

```text
iOS/**
.github/workflows/ios-ci.yml
```

Worker CI:

```text
worker/**
.github/workflows/worker-ci.yml
```

Docs/API check:

```text
docs/**
outputs/**
```

## Worker Secrets

GitHub:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

Cloudflare Worker secrets:

- `ALADIN_API_KEY`
- `DATA4LIBRARY_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

Do not print, upload, or commit secrets, decoded service-account JSON, Firebase plist contents, provisioning profiles, or APNs/private keys. CI should validate presence and shape only.

## API Contract Automation

Use fixtures:

```text
docs/fixtures/
├─ books-search-response.json
├─ books-detail-response.json
├─ books-trending-response.json
└─ books-availability-response.json
```

Validate:

- Worker returns schema-compatible responses.
- iOS DTO decodes fixtures.

## Success Criteria

- Worker PRs run typecheck/test/lint.
- iOS PRs run simulator build/test.
- Worker deploys to Cloudflare on main merge.
- iOS release build check can run.
- Firebase required config is detected by CI.
