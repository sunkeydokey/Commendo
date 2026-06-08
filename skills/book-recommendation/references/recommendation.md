# Recommendation Reference

## v1 Rule Score

| Factor | Example weight |
| :-- | --: |
| Category/KDC match | +30 |
| Keyword similarity | +20 |
| Author match | +15 |
| Hot/trending book | +10 |
| Recent behavior | +5 to +20 |
| Repeated exposure penalty | -10 |

Reasons:

- `최근 저장한 책과 같은 분야예요`
- `관심 있게 본 책과 주제가 비슷해요`
- `전에 본 작가의 다른 책이에요`
- `요즘 도서관에서 많이 읽히는 책이에요`

## Core ML v2

Model type:

- Binary classifier/ranker.
- Input: user-book numeric features.
- Output: ranking score, not directly shown as probability.

Feature candidates:

- `categoryAffinity`
- `keywordSimilarity`
- `authorAffinity`
- `trendScore`
- `recencyScore`
- `isBookmarkedBefore`
- `seenCount`
- `publicationAge`

Model candidates:

- Logistic Regression first.
- Gradient Boosted Trees later.

Training:

1. Generate synthetic or locally anonymized sample behavior logs.
2. Train in Python.
3. Convert to Core ML.
4. Bundle `.mlmodel`.
5. Use inference only in the app.

Do not export real user behavior logs, raw search terms, device identifiers, or bookmark histories for training in MVP.

## Hybrid Score v3

```text
finalScore =
  coreMLScore * 0.55
  + ruleScore * 0.25
  + trendScore * 0.15
  + freshnessScore * 0.05
```

## Cold Start

| State | Strategy |
| :-- | :-- |
| First launch | Trend/new arrivals |
| Search >= 1 | Search keywords |
| Detail views >= 3 | Recently viewed similarity |
| Bookmark >= 1 | Category/keyword preference |
| Bookmark >= 5 | Stronger personalization |

## Score Display

Avoid exact percent by default.

Preferred:

- `잘 맞을 가능성이 높아요`
- `관심 분야와 가까워요`
- `최근 본 책과 비슷해요`

If using percent-like display, bucket scores into wording instead of showing raw model output.
