---
name: book-recommendation
description: Use when designing or implementing the book recommendation algorithm for the iOS book curation app, including rule-based scoring, local SwiftData behavior logs, BookFeature/UserPreferenceProfile, recommendation explanations, cold start, Core ML ranking, and hybrid scoring.
---

# Book Recommendation

Use this skill for recommendation design and implementation.
Also follow `skills/project-workflow/SKILL.md` when completing work.

## Strategy

Build recommendation in stages:

1. v1: Rule-based local scoring.
2. v2: Core ML ranking model.
3. v3: Hybrid score using Core ML, rules, trend, and freshness.

Core ML is not required for MVP. The recommendation feature must work without it.

## Core Principles

- Do not store the full book DB locally.
- Score only the candidate books the app currently knows.
- Store user behavior and preferences locally in SwiftData.
- Do not upload local behavior logs or per-user recommendation profiles to Worker, Firebase Analytics, Crashlytics, or third-party model services in MVP.
- Do not expose internal scores as exact probabilities.
- Generate recommendation reasons from feature/rule contributions, not from LLM text generation.

## Candidate Sources

- Trend books.
- New arrivals.
- Search results.
- Related books from Data4Library.
- Books sharing categories/keywords with bookmarks.

## References

Read `references/recommendation.md` for scoring features, labels, cold start, model choices, and success criteria.
