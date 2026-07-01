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

- Invalid query parameters return `400` with `{ "error": "<stable_error_code>" }`.
- Validation happens before provider fetches, Worker Cache access, or D1 access.
- Unknown query parameters are ignored.

Current route parameters:

| Parameter | Routes | Rule | Error code |
| :-- | :-- | :-- | :-- |
| `q` | `/books/search` | Trimmed length 2-50 chars. | `invalid_query` |
| `isbn` | `/books/detail` | Trimmed 10 or 13 numeric chars. | `invalid_isbn` |
| `page` | `/books/search`, `/books/trending`, `/books/new-arrivals` | Positive safe integer, default `1`. | `invalid_page` |
| `pageSize` | `/books/search`, `/books/trending`, `/books/new-arrivals` | Positive safe integer, default `20`, max `20`. | `invalid_page_size` |
| `type` | `/books/new-arrivals` | `all` or `special`, default `all`. | `invalid_type` |

Future availability routes should use allowlisted `region` and `libCode` values before calling Data4Library.

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
