---
name: book-ios-app
description: Use when implementing the iOS client for the book curation app, including SwiftData local storage, tab/coordinator structure, API client integration with the Cloudflare Worker, Firebase SDK integration, screen states, Book Detail, Availability, and Library behavior.
---

# Book iOS App

Use this skill for iOS app implementation decisions.
Also follow `skills/project-workflow/SKILL.md` when completing work.

## App Structure

Tabs:

- Trend
- Search
- Recommend
- Library

Navigation:

```text
TabCoordinator
├─ TrendCoordinator -> BookDetailCoordinator -> AvailabilityCoordinator
├─ SearchCoordinator -> BookDetailCoordinator -> AvailabilityCoordinator
├─ RecommendCoordinator -> BookDetailCoordinator -> AvailabilityCoordinator
└─ LibraryCoordinator -> BookDetailCoordinator -> AvailabilityCoordinator
```

Book Detail is reused from all tabs. Availability is only pushed from Book Detail.

## Local Storage

Use SwiftData.

Store:

- Bookmarks.
- Recently viewed books.
- Recent searches.
- User behavior events.
- Recommendation features/profile.

Do not upload personal behavior logs to Cloudflare in MVP.
Do not send raw search terms, full book titles from user activity, local behavior event payloads, or device identifiers to Analytics, Crashlytics custom keys, Performance attributes, or Worker logs.

## API Client

The iOS app calls only the Worker API. It never calls Aladin or Data4Library directly and never contains external API keys.
Do not commit Firebase plist files, API keys, APNs keys, service-account JSON, or generated credential files unless the file is explicitly intended to be public client configuration and reviewed.

## UI States

Every network screen needs:

- Loading.
- Empty.
- Error.
- Stale cache with last updated time.
- Bookmark on/off.

## References

Read `references/ios-implementation.md` for screens, SwiftData models, Firebase integration, and implementation priority.
