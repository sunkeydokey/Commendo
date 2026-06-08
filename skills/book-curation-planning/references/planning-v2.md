# Planning Reference

Source summary from `iOS_Book_Curation_App_Planning_v2.md`.

## Product

An iOS book curation app showing new books, library loan trends, search, detail, availability, and personalized recommendations.

Architecture:

```text
iOS App
  -> Firebase
    -> Messaging
    -> Crashlytics
    -> Analytics
    -> Remote Config
    -> Performance Monitoring
  -> Cloudflare Worker API Proxy
    -> Aladin Open API
    -> Data4Library API
```

## Worker Endpoints

| Endpoint | Role |
| :-- | :-- |
| `GET /books/trending` | New arrivals, hot trends, monthly keywords |
| `GET /books/search` | Book search |
| `GET /books/detail` | Book detail, usage analysis, related recommendations |
| `GET /books/availability` | Libraries holding a book |
| `GET /libraries/book-exist` | Availability in a specific library |
| `POST /notifications/register` | Register FCM token |
| `POST /notifications/unregister` | Disable/remove FCM token |

## Screens

- Trend: new books, hot loan trends, monthly keywords, recently viewed.
- Search: search input, recent searches, result list, detail navigation.
- Book Detail: metadata, description, fit explanation, usage summary, related books, bookmark, availability CTA.
- Recommend: personalized recommendations, similar-to-recent, saved-field-based, trend-boosted.
- Library: bookmarks, recently viewed, recent searches.
- Availability: ISBN + region library list, loan status, no library detail.

## Firebase

Included:

- Messaging
- Crashlytics
- Analytics
- Remote Config
- Performance Monitoring

Excluded:

- App Check
- App Distribution

## Success Criteria

- Search/detail/trend flow works through Worker.
- External API keys are not in the app.
- Same query/ISBN can reuse shared cache.
- SwiftData stores local user data.
- FCM push works when new-arrival snapshot changes.
- Analytics/Remote Config/Performance Monitoring are integrated.
- Raw search terms, behavior logs, FCM tokens, APNs tokens, and device identifiers are not logged, sent to analytics, or exposed through debug endpoints.
