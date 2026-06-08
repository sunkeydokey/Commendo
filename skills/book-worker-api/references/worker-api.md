# Worker API Reference

## External API Map

| Worker endpoint | External APIs |
| :-- | :-- |
| `/books/trending` | Aladin `ItemList.aspx`, Data4Library `hotTrend`, `monthlyKeywords`, `newArrivalBook` |
| `/books/search` | Aladin `ItemSearch.aspx`, Data4Library `srchBooks` |
| `/books/detail` | Aladin `ItemLookUp.aspx`, Data4Library `srchDtlList`, `usageAnalysisList`, `recommandList` |
| `/books/availability` | Data4Library `libSrchByBook` |
| `/libraries/book-exist` | Data4Library `bookExist` |

## Validation

- `q`: trim, 2-50 chars.
- `isbn`: 10 or 13 numeric chars.
- `page`: integer >= 1.
- `pageSize`: max 20.
- `region`: allowlisted region code.
- Unknown params: ignore or return 400.

## Shared Cache

Cache public, non-user-specific data:

| Data | Key | TTL |
| :-- | :-- | :-- |
| Search | endpoint + hash(normalized query) + page + pageSize | 5-30 min |
| Detail | endpoint + ISBN | 1-7 days |
| Trend | endpoint + date/category | 6-24 hours |
| Usage analysis | endpoint + ISBN | 1 day |
| Availability | endpoint + ISBN + region | 5-30 min |
| Book exist | endpoint + ISBN + libCode | 1-5 min |

Do not cache personal recommendation scores, bookmarks, recent searches, or user profile data in Worker shared cache.
Do not put raw search terms, FCM tokens, authorization headers, or upstream response bodies in logs, cache keys, analytics events, or error responses.

## D1 Tables

Use D1 for:

- `new_arrival_snapshots`
- `notification_devices`
- `notification_logs`

Store only the minimum notification device data needed for FCM delivery and unsubscribe. Delete or disable tokens on unregister, and never expose token values through list/debug endpoints.

Snapshot diff key:

```text
todayNewArrivalISBNs - previousNewArrivalISBNs = changedISBNs
```

Fallback key when ISBN is missing:

```text
title + authors + publisher
```

## Scheduled Push

KST 09:00 is UTC 00:00:

```toml
[triggers]
crons = ["0 0 * * *"]
```

Flow:

```text
scheduled()
  -> fetchNewArrivals()
  -> diffSnapshots()
  -> saveSnapshot()
  -> sendPushIfChanged()
```

Use FCM HTTP v1. FCM still delivers to iOS through APNs.
