# 추천 지수 산정 방식

Commendo의 추천 지수는 사용자의 북마크를 기기 안에서만 읽어 계산하는 로컬 개인화 점수입니다. 서버로 사용자 북마크, 평점, 검색어, 추천 프로필을 보내지 않습니다.

추천 지수는 0부터 100까지의 정수로 표시하지만, 실제 만족 확률은 아닙니다. 현재 후보 도서가 사용자의 저장 도서와 얼마나 가까운지, 공개 추천 관계 모델과 규칙 점수가 어느 정도 일치하는지를 보여주는 랭킹용 점수입니다.

## 전체 흐름

```text
후보 도서 + 상세 정보 + 로컬 북마크
-> BookFeature 생성
-> UserPreferenceProfile 생성
-> RecommendationModelInput 생성
-> 규칙 점수 계산
-> Core ML 점수 계산 가능하면 혼합
-> 0...100 추천 지수와 추천 이유 생성
```

관련 파일:

- `RecommendationTypes.swift`: 후보 도서 피처, 사용자 선호 프로필, 결과 타입
- `RecommendationScoringService.swift`: 규칙 점수, Core ML 추론, 최종 점수 혼합
- `BookRecommendationRanker.mlmodel`: Data4Library 약한 라벨 기반 Core ML 랭커

## 후보 도서 피처

`BookFeature`는 추천을 계산할 후보 도서에서 다음 값을 뽑습니다.

| 피처 | 의미 |
| :-- | :-- |
| `categoryName` | 상세 API에서 받은 카테고리 이름 |
| `keywords` | 제목, 저자, 출판사, 카테고리, 소개 문구를 단순 토큰화한 키워드 |
| `publicationYear` | 출간연도 |
| `trendSignal` | 베스트셀러/인기 흐름 화면에서 들어온 후보에 부여하는 약한 신호 |
| `newArrivalSignal` | 신간 화면에서 들어온 후보에 부여하는 약한 신호 |
| `relatedBookSignal` | 상세 화면의 관련 도서에서 들어온 후보에 부여하는 약한 신호 |
| `searchResultSignal` | 검색 결과에서 들어온 후보에 부여하는 약한 신호 |
| `trendOrRelatedSignal` | Core ML 호환성을 위해 위 출처 신호를 하나로 모은 기존 집계 피처 |

키워드는 영문/숫자/한글을 기준으로 분리하고, 길이 2 이상 토큰만 사용합니다. 형태소 분석이나 동의어 확장은 아직 적용하지 않습니다.

## 사용자 선호 프로필

`UserPreferenceProfile`은 SwiftData에 저장된 `BookBookmark` 목록에서 매번 다시 계산합니다. 북마크가 추가, 수정, 삭제되면 다음 계산부터 추천 지수에 반영됩니다.

높은 평점 북마크는 선호 신호가 됩니다.

- 평점 `3.0` 이상: 선호 저자, 선호 카테고리, 선호 키워드에 가중치 누적
- 상세 카테고리가 있으면 전체 카테고리와 상위 카테고리를 함께 누적
- 상위 카테고리는 예를 들어 `국내도서>인문>철학`에서 `국내도서>인문`까지 사용

낮은 평점 북마크는 비선호 신호가 됩니다.

- 평점 `3.0` 미만: 비선호 저자, 비선호 카테고리, 비선호 키워드에 기록
- 후보 도서가 비선호 요소와 겹치면 규칙 점수에서 감점

북마크 하나의 선호 가중치는 평점과 최근성을 곱해 계산합니다. 프로필은 저자, 카테고리, 키워드별 최신 매칭 날짜도 함께 저장해 후보 도서와 실제로 겹친 선호 신호의 나이를 계산합니다.

```text
ratingWeight = max(0, (rating - 2.5) / 2.5)
recencyWeight = max(0.25, 1 - min(ageInDays / 180, 0.75))
bookmarkWeight = ratingWeight * recencyWeight
```

즉, 평점이 높고 최근에 수정한 북마크일수록 추천에 더 강하게 반영됩니다. 오래된 북마크도 최소 25%의 최근성 가중치는 유지합니다.

## 모델 입력 피처

규칙 점수와 Core ML 모델은 같은 `RecommendationModelInput`을 사용합니다.

| 피처 | 산정 방식 |
| :-- | :-- |
| `categoryAffinity` | 후보 카테고리가 선호 카테고리와 정확히 일치하거나 상위 카테고리/키워드가 겹치는 정도 |
| `keywordSimilarity` | 후보 키워드 중 선호 키워드와 겹치는 가중 비율 |
| `authorAffinity` | 후보 저자가 선호 저자와 일치하는 정도 |
| `ratingAffinity` | 현재는 `authorAffinity`와 `keywordSimilarity` 중 큰 값 |
| `recencyScore` | 후보와 실제로 매칭된 저자/키워드/카테고리 신호가 180일 이내일수록 높은 값 |
| `publicationAge` | 출간 10년 이내일수록 높은 값 |
| `trendOrRelatedSignal` | 트렌드, 신간, 관련 도서, 검색 결과 출처 신호의 Core ML 호환 집계값 |

모든 피처는 `0...1` 범위로 맞춥니다.

## 규칙 점수

북마크가 없으면 콜드스타트 점수를 사용합니다.

```text
ruleScore =
  0.35
  + trendOrRelatedSignal * 0.15
  + publicationAge * 0.05
```

북마크가 하나 이상 있으면 개인화 규칙 점수를 사용합니다.

```text
ruleScore =
  0.25
  + categoryAffinity * 0.20
  + keywordSimilarity * 0.25
  + authorAffinity * 0.15
  + ratingAffinity * 0.15
  + recencyScore * 0.10
  + trendOrRelatedSignal * 0.05
  + publicationAge * 0.05
  - dislikedAuthorPenalty
  - dislikedKeywordPenalty
  - dislikedCategoryPenalty
```

감점은 다음과 같습니다.

| 조건 | 감점 |
| :-- | --: |
| 비선호 저자와 일치 | `-0.15` |
| 비선호 키워드와 겹침 | `-0.10` |
| 비선호 카테고리와 일치 | `-0.12` |

마지막에는 `0...1` 범위로 잘라냅니다.

## Core ML 모델 점수

`BookRecommendationRanker.mlmodel`은 위 7개 입력 피처를 받아 `score`를 반환합니다. 모델이 없거나 추론에 실패하면 규칙 점수만 사용합니다.

모델은 실제 사용자 행동 로그가 아니라 Data4Library 추천 관계를 약한 라벨로 사용해 학습한 랭커입니다. 따라서 모델 출력은 실제 만족 확률이 아니며, 앱에서는 규칙 점수와 섞어 보정합니다.

## 최종 추천 지수

북마크가 없거나 모델 점수를 사용할 수 없으면 규칙 점수만 사용합니다.

```text
finalScore = ruleScore
```

모델 점수를 사용할 수 있으면 북마크 수에 따라 혼합 비율을 바꿉니다.

| 북마크 수 | 모델 비중 | 규칙 비중 |
| --: | --: | --: |
| 1-2개 | 35% | 65% |
| 3-4개 | 50% | 50% |
| 5개 이상 | 60% | 40% |

```text
finalScore = modelScore * modelWeight + ruleScore * (1 - modelWeight)
recommendationIndex = round(finalScore * 100)
```

북마크가 적을수록 로컬 규칙 개인화를 더 믿고, 북마크가 충분히 쌓이면 Core ML 랭커의 비중을 조금 높입니다.

## 신뢰도

추천 신뢰도는 모델 사용 여부와 북마크 수로 정합니다.

| 조건 | 신뢰도 |
| :-- | :-- |
| 모델 미사용 또는 북마크 2개 미만 | 낮음 |
| 북마크 2-4개 | 보통 |
| 북마크 5개 이상 | 높음 |

## 추천 이유

추천 이유는 모델 내부값이 아니라 로컬 피처 기여도에서 생성합니다.

- 같은 저자: `저장한 책과 같은 저자의 도서예요`
- 키워드 유사: `최근 높게 평가한 책과 주제가 비슷해요`
- 카테고리 유사: `최근 저장한 책과 같은 분야예요`
- 출처 신호: `함께 읽기 좋은 도서와 연결돼 있어요`
- 비선호 요소 감점: `낮게 평가한 책과 겹치는 요소가 있어 점수를 낮췄어요`

표시할 이유는 최대 2개로 제한합니다.

## 현재 한계와 다음 개선 후보

- `ratingAffinity`가 `authorAffinity`와 `keywordSimilarity`의 최댓값이라 신호 중복이 있습니다.
- `trendOrRelatedSignal`은 Core ML 호환성 때문에 모델 입력에서는 여전히 단일 집계 피처입니다. 앱 내부의 출처 신호는 `BookFeature`에서 분리해 유지합니다.
- 키워드 추출은 단순 토큰화라 한국어 형태소, 불용어, 동의어 처리는 하지 않습니다.
