---
name: project-cache-safety
description: Use when adding, changing, debugging, deploying, or reviewing caching in Commendo, including Cloudflare Worker Cache keys and routes, Cache-Control TTLs, SunKit query keys and lifetimes, response-contract changes, stale or empty cached responses, provider fallbacks, and cache invalidation after API changes.
---

# Project Cache Safety

Use this skill for every change that affects cached API data or a cached response contract. Also follow `skills/book-worker-api/SKILL.md`, `skills/book-ios-app/SKILL.md`, `skills/project-testing/SKILL.md`, and `skills/project-workflow/SKILL.md` when their areas change.

## Map Every Cache Layer

Before editing, identify all cache layers for the route:

1. Worker cache key and `caches.default` reads/writes.
2. HTTP `Cache-Control` headers and CDN behavior.
3. SunKit query key, `staleTime`, and `gcTime`.
4. Any image or persistent cache that consumes the response.

Search the repository for the route path, response model, cache-key builder, `QueryCacheOptions`, and `.query(` call. Do not assume changing one layer invalidates another.

## Version Response Contracts

When a cached response adds, removes, renames, or changes the meaning of a field:

- Increment the Worker cache-key version.
- Increment the corresponding SunKit query-key version.
- Update decoding tests with the complete new response shape.
- Keep version tokens explicit and searchable, such as `version=4` and `"v3"`.
- Report which old cached payloads the version change invalidates.

Never deploy a response-contract change while reusing the previous Worker or SunKit key.

## Cache Only Complete Success

Classify upstream outcomes before writing to cache:

- **Complete success:** required providers succeeded; cache normally.
- **Legitimate empty result:** provider succeeded and explicitly returned no items; cache only when emptiness is valid product data.
- **Partial failure:** an optional provider timed out, failed, or returned an invalid shape; return a safe fallback if appropriate, but do not cache that degraded response.
- **Required-provider failure:** return an error response and do not cache it.

Do not convert provider failure to `[]` and then cache it as a legitimate empty result. Track provider availability separately from the fallback value.
Set degraded responses to `Cache-Control: no-store`; skipping `caches.default.put` alone is not a complete cache policy.

Every external provider request must have an explicit timeout. Optional providers must not block required route data indefinitely.

## Cache-Key Rules

- Build keys from a fixed route and normalized validated parameters.
- Include every parameter that changes the response.
- Exclude secrets, authorization headers, and raw provider URLs.
- Keep query-parameter ordering deterministic.
- Use one cache-key builder per route instead of duplicating key construction.
- Bump the version when normalization or fallback semantics change, even if JSON field names do not.

## Route Verification

Before deployment:

1. Run `npm run typecheck`.
2. Run Wrangler dry-run packaging.
3. Run iOS build and focused unit tests when the shared contract or SunKit key changes.

After deployment, call the public Worker route with at least:

1. A known non-empty result.
2. A known legitimate empty result.
3. A previously failing or slow provider case.
4. The same successful request twice to check first-load behavior and subsequent cache HIT.

Verify HTTP status, response shape, item count, elapsed time, `Cache-Control`, `cf-cache-status`, and `age`. Do not treat HTTP 200 alone as success.

When testing degraded optional-provider behavior, confirm repeated requests retry the provider rather than serving a cached degraded response.

## Deployment Sequence

For a Worker contract consumed by iOS:

1. Make the Worker backward compatible when practical.
2. Deploy and verify the Worker route.
3. Update and verify the iOS model and SunKit key.
4. Commit Worker and iOS changes as separate verifiable units when they can stand independently.
5. Push only after route verification and local checks pass.

## Completion Report

State:

- Worker and SunKit key versions changed.
- Which responses are cacheable and non-cacheable.
- TTL values.
- Route cases tested and their item counts.
- Deployment version, when deployed.
- Build and test results.
