---
name: book-worker-api
description: Use when implementing or modifying the Cloudflare Worker API proxy for the iOS book curation app, including Aladin/Data4Library endpoint mapping, secret handling, input validation, Worker Cache, D1 snapshot/token tables, rate limiting, and FCM send requests.
---

# Book Worker API

Use this skill for the Cloudflare Worker backend layer.

## Responsibilities

The Worker is a fixed-route API proxy, not a generic proxy.

It handles:

- External API key secrecy.
- Aladin/Data4Library request construction.
- Input validation.
- Shared cache for public API responses.
- D1 storage for new-arrival snapshots, FCM tokens, and notification logs.
- Scheduled new-arrival diff jobs.
- FCM HTTP v1 message send requests.

Never implement `/proxy?url=...`.

## Required Routes

- `GET /books/trending`
- `GET /books/search`
- `GET /books/detail`
- `GET /books/availability`
- `GET /libraries/book-exist`
- `POST /notifications/register`
- `POST /notifications/unregister`
- `POST /notifications/preferences` when notification settings are needed

## Storage Boundary

- Worker Cache: search/detail/trending/availability responses.
- D1: snapshots, FCM tokens, notification logs.
- No personal behavior logs in Cloudflare for MVP.

## Security Rules

- Store `ALADIN_API_KEY`, `DATA4LIBRARY_API_KEY`, and Firebase service credentials as Worker secrets.
- Do not return secrets in responses, error messages, or logs.
- Do not log raw search queries, ISBN request histories, FCM tokens, authorization headers, or upstream response bodies.
- Validate query parameters before calling external APIs.
- Restrict `pageSize` to a small maximum, default 20.
- Use fixed endpoints and normalized cache keys. For user-entered search text, prefer a hashed normalized query in cache keys rather than the raw query string.
- Accept notification registration only over HTTPS and store only the minimum device fields needed to send or revoke FCM messages.

## References

Read `references/worker-api.md` for endpoint mapping, cache policy, storage tables, and scheduled job flow.
