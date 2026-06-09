---
name: book-curation-planning
description: Use when planning, reviewing, or refining the iOS book curation app product scope, MVP boundaries, screen structure, user flows, data-source responsibilities, or project documentation. Applies to the app using Aladin Open API, Data4Library, Cloudflare Worker proxy, Firebase, SwiftData, and local recommendation.
---

# Book Curation Planning

Use this skill to keep product decisions consistent before implementation.
Also follow `skills/project-workflow/SKILL.md` when completing work.

## Core Positioning

The product is an iOS book curation app that combines:

- Aladin Open API for book metadata, search, list, cover, and commercial publication data.
- Data4Library for public library trends, usage analysis, recommendations, and availability.
- Cloudflare Worker as a lightweight API proxy.
- SwiftData for local personal data.
- Firebase for push, crash, analytics, remote config, and performance.
- Rule-based recommendation first, Core ML later.

## MVP Scope

Include:

- Trend
- Search
- Book Detail
- Recommend
- Library as personal shelf
- Availability from Book Detail
- Worker API Proxy
- Worker Cache
- SwiftData local storage
- Firebase Messaging, Crashlytics, Analytics, Remote Config, Performance Monitoring

Exclude:

- Project name finalization
- Login/account
- Server DB for personal behavior logs
- Library Detail
- Map-based library browsing
- Reviews/community
- Payment/purchase
- Firebase App Check
- Firebase App Distribution
- Server-personalized push
- Full book DB stored locally

## Screen Rules

- Tab structure: Trend / Search / Recommend / Library.
- Book Detail is reusable from all tabs.
- Availability is pushed only from Book Detail.
- Library means personal shelf, not public library detail.
- Do not add Library Detail to MVP.

## Data Boundaries

- iOS SwiftData: bookmarks, recently viewed books, recent searches, behavior events, recommendation feature/profile.
- Cloudflare D1: new-arrival snapshots, FCM tokens, notification logs.
- Worker Cache: search, detail, trend, availability API responses.
- External API keys never go into the iOS app.
- Raw search terms, behavior logs, FCM tokens, APNs tokens, and device identifiers must not be logged or sent to analytics.

## References

Read `references/planning-v2.md` when needing the full product plan, screen descriptions, API map, risks, and success criteria.
