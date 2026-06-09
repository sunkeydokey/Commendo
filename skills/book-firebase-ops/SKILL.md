---
name: book-firebase-ops
description: Use when integrating or planning Firebase for the iOS book curation app, including Firebase Messaging push through FCM/APNs, Crashlytics, Analytics, Remote Config, Performance Monitoring, new-arrival notification flows, and Firebase feature boundaries.
---

# Book Firebase Ops

Use this skill for Firebase-related implementation and operations.
Also follow `skills/project-workflow/SKILL.md` when completing work.

## Included Firebase Products

- Firebase Cloud Messaging.
- Firebase Crashlytics.
- Firebase Analytics.
- Firebase Remote Config.
- Firebase Performance Monitoring.

## Excluded Firebase Products

- Firebase App Check.
- Firebase App Distribution.

## Push Principle

iOS push is sent through FCM, but FCM delivers to Apple devices through APNs. The project still needs Push Notifications capability and APNs authentication key configured in Firebase Console.

Worker sends messages to FCM HTTP v1; Worker does not directly implement APNs provider logic.

## Security Rules

- Keep APNs keys, Firebase service-account credentials, and private keys out of the repository.
- Do not log FCM tokens, APNs tokens, authorization headers, private keys, or full FCM request/response bodies.
- Do not put raw search terms, full book titles from user activity, device identifiers, or local behavior events in Analytics, Crashlytics custom keys, Remote Config, or Performance attributes.
- Use Remote Config only for non-secret operational values.

## References

Read `references/firebase-ops.md` for notification flow, required secrets, events, Remote Config parameters, and performance traces.
