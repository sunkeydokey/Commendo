# iOS Implementation Reference

## Screens

Trend:

- New books.
- Hot loan trend.
- Monthly keywords.
- Recently viewed shortcut.

Search:

- Search input.
- Recent searches.
- Result list.
- Navigate to Book Detail.

Book Detail:

- Cover/title/authors/publisher/published date.
- Description.
- Personal fit explanation.
- Usage summary.
- Related books.
- Bookmark.
- `소장 도서관 찾기` CTA.

Recommend:

- Personalized recommendations.
- Similar to recently viewed.
- Saved-field-based recommendations.
- Trend-boosted recommendations.

Library:

- Bookmarks.
- Recently viewed.
- Recent searches.

Availability:

- ISBN + region library list.
- Loan status.
- No Library Detail.

## SwiftData Model Candidates

- `StoredBook`
- `Bookmark`
- `RecentBook`
- `RecentSearch`
- `UserBehaviorEvent`
- `BookFeature`
- `UserPreferenceProfile`

Keep schema simple for MVP to reduce migration risk.

## Firebase

Include:

- Messaging for FCM token and push receive.
- Crashlytics with dSYM upload.
- Analytics for minimal events.
- Remote Config for operational weights and TTLs.
- Performance Monitoring for search/detail/trend/availability latency.

Excluded:

- App Check.
- App Distribution.

## Analytics Events

- `search_submitted`
- `book_detail_opened`
- `bookmark_added`
- `bookmark_removed`
- `recommendation_clicked`
- `availability_opened`
- `notification_opened`

Avoid sending raw search terms or full book titles. Use coarse metadata only, such as result count bucket, source screen, latency bucket, and success/failure.

## Client-Side Security Notes

- Keep external API keys out of the app bundle.
- Keep personal behavior logs in SwiftData for MVP.
- Do not attach raw user activity, FCM tokens, or device identifiers to Crashlytics custom keys, Analytics parameters, Performance trace attributes, or debug logs.
- Treat Firebase plist files and entitlement changes as security-sensitive review items before commit.
