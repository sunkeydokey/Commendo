# Firebase Ops Reference

## FCM New Arrival Push

Flow:

```text
Cloudflare Cron Trigger
  -> Worker scheduled handler
    -> Fetch new arrivals
    -> Diff snapshot
    -> Find FCM tokens
    -> Send FCM HTTP v1 message
    -> FCM delivers through APNs
```

KST 09:00:

```toml
[triggers]
crons = ["0 0 * * *"]
```

Worker secrets:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

Device table stores `fcmToken`, not raw APNs token.
Never log or expose stored token values. Unregister should delete or disable the token record, and notification logs should store delivery metadata without token values.

## Notification Copy

MVP generic push:

- `새로운 신간 도서가 있어요. 내 취향과 비교해보세요.`
- `오늘 업데이트된 신간을 확인해보세요.`

Server-personalized push is excluded from MVP.

## Analytics Events

- `search_submitted`
- `book_detail_opened`
- `bookmark_added`
- `bookmark_removed`
- `recommendation_clicked`
- `availability_opened`
- `notification_opened`

Avoid raw search queries and full book titles. Use coarse metadata only, such as source screen, result count bucket, latency bucket, and success/failure.

## Remote Config

Initial parameters:

- `search_cache_ttl_minutes`
- `detail_cache_ttl_hours`
- `recommendation_weight_category`
- `recommendation_weight_keyword`
- `recommendation_weight_trend`
- `new_arrival_push_enabled`
- `minimum_supported_app_version`

Do not store secrets in Remote Config.
Do not store user identifiers, FCM tokens, search terms, or per-user preference data in Remote Config.

## Performance Monitoring

Trace:

- Search latency.
- Detail load latency.
- Trend load latency.
- Availability latency.
- App startup time.
