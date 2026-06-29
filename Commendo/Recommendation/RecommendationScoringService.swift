//
//  RecommendationScoringService.swift
//  Commendo
//
//  Created by Codex on 6/25/26.
//

import CoreML
import Foundation

protocol RecommendationRanker {
  func score(input: RecommendationModelInput) -> Double?
}

struct CoreMLRecommendationRanker: RecommendationRanker {
  private let model: MLModel?

  init(modelName: String = "BookRecommendationRanker", bundle: Bundle = .main) {
    if let compiledURL = bundle.url(forResource: modelName, withExtension: "mlmodelc") {
      model = try? MLModel(contentsOf: compiledURL)
    } else {
      model = nil
    }
  }

  func score(input: RecommendationModelInput) -> Double? {
    guard let model,
          let provider = try? MLDictionaryFeatureProvider(dictionary: [
            "categoryAffinity": input.categoryAffinity,
            "keywordSimilarity": input.keywordSimilarity,
            "authorAffinity": input.authorAffinity,
            "ratingAffinity": input.ratingAffinity,
            "recencyScore": input.recencyScore,
            "publicationAge": input.publicationAge,
            "trendOrRelatedSignal": input.trendOrRelatedSignal,
          ]),
          let prediction = try? model.prediction(from: provider) else {
      return nil
    }

    let candidateNames = [
      model.modelDescription.predictedFeatureName,
      "score",
      "rankingScore",
      "probability",
      "targetProbability",
    ].compactMap(\.self)

    for name in candidateNames {
      if let value = prediction.featureValue(for: name)?.doubleValue {
        return value.clamped(to: 0...1)
      }
    }

    return nil
  }
}

struct RecommendationScoringService {
  private let ranker: RecommendationRanker?
  private let now: () -> Date

  init(
    ranker: RecommendationRanker? = CoreMLRecommendationRanker(),
    now: @escaping () -> Date = Date.init
  ) {
    self.ranker = ranker
    self.now = now
  }

  func score(
    book: BookSummary,
    detail: BookDetail? = nil,
    bookmarks: [BookBookmark],
    sourceContext: RecommendationSourceContext = .none
  ) -> RecommendationResult {
    let feature = BookFeature(
      book: book,
      detail: detail,
      sourceContext: sourceContext
    )
    let profile = UserPreferenceProfile(bookmarks: bookmarks, now: now())
    let input = modelInput(feature: feature, profile: profile)
    let ruleScore = ruleScore(input: input, feature: feature, profile: profile)

    let score: Int
    let modelScore = profile.hasEnoughBookmarksForModel ? ranker?.score(input: input) : nil
    let usedModel = modelScore != nil

    let modelWeight = modelBlendWeight(profile: profile, usedModel: usedModel)
    if let modelScore, modelWeight > 0 {
      score = Int(round((modelScore * modelWeight + ruleScore * (1 - modelWeight)) * 100))
    } else {
      score = Int(round(ruleScore * 100))
    }

    return RecommendationResult(
      score: score,
      confidence: confidence(profile: profile, usedModel: usedModel),
      reasons: reasons(input: input, feature: feature, profile: profile)
    )
  }

  private func modelInput(
    feature: BookFeature,
    profile: UserPreferenceProfile
  ) -> RecommendationModelInput {
    let authorAffinity = profile.preferredAuthors[feature.author].clamped(maximum: 1)
    let keywordSimilarity = similarity(
      candidateKeywords: feature.keywords,
      preferredKeywords: profile.preferredKeywords
    )
    let ratingAffinity = max(authorAffinity, keywordSimilarity)
    let recencyScore = recencyScore(feature: feature, profile: profile)
    let publicationAge = publicationAgeScore(year: feature.publicationYear)

    return RecommendationModelInput(
      categoryAffinity: categoryAffinity(feature: feature, profile: profile),
      keywordSimilarity: keywordSimilarity,
      authorAffinity: authorAffinity,
      ratingAffinity: ratingAffinity,
      recencyScore: recencyScore,
      publicationAge: publicationAge,
      trendOrRelatedSignal: feature.trendOrRelatedSignal
    )
  }

  private func ruleScore(
    input: RecommendationModelInput,
    feature: BookFeature,
    profile: UserPreferenceProfile
  ) -> Double {
    guard profile.bookmarkCount > 0 else {
      return 0.35 + input.trendOrRelatedSignal * 0.15 + input.publicationAge * 0.05
    }

    var score = 0.25
    score += input.categoryAffinity * 0.20
    score += input.keywordSimilarity * 0.25
    score += input.authorAffinity * 0.15
    score += input.ratingAffinity * 0.15
    score += input.recencyScore * 0.10
    score += input.trendOrRelatedSignal * 0.05
    score += input.publicationAge * 0.05

    if profile.dislikedAuthors.contains(feature.author) {
      score -= 0.15
    }

    if !feature.keywords.isDisjoint(with: profile.dislikedKeywords) {
      score -= 0.10
    }

    if matchesDislikedCategory(feature: feature, profile: profile) {
      score -= 0.12
    }

    return score.clamped(to: 0...1)
  }

  private func categoryAffinity(
    feature: BookFeature,
    profile: UserPreferenceProfile
  ) -> Double {
    guard !feature.categoryName.isEmpty else {
      return 0
    }

    let rootCategory = BookFeature.categoryRoot(from: feature.categoryName)
    let exactMatch = profile.preferredCategories[feature.categoryName].clamped(maximum: 1)
    let rootMatch = profile.preferredCategories[rootCategory].clamped(maximum: 1) * 0.8
    let keywordMatch = similarity(
      candidateKeywords: BookFeature.keywords(from: feature.categoryName),
      preferredKeywords: profile.preferredKeywords
    )
    return max(exactMatch, rootMatch, keywordMatch)
  }

  private func matchesDislikedCategory(
    feature: BookFeature,
    profile: UserPreferenceProfile
  ) -> Bool {
    guard !feature.categoryName.isEmpty else {
      return false
    }

    let rootCategory = BookFeature.categoryRoot(from: feature.categoryName)
    return profile.dislikedCategories.contains(feature.categoryName)
      || (!rootCategory.isEmpty && profile.dislikedCategories.contains(rootCategory))
  }

  private func similarity(
    candidateKeywords: Set<String>,
    preferredKeywords: [String: Double]
  ) -> Double {
    guard !candidateKeywords.isEmpty, !preferredKeywords.isEmpty else {
      return 0
    }

    let matchedWeight = candidateKeywords.reduce(0) { total, keyword in
      total + min(preferredKeywords[keyword] ?? 0, 1)
    }
    let denominator = Double(max(candidateKeywords.count, 1))
    return (matchedWeight / denominator).clamped(to: 0...1)
  }

  private func recencyScore(
    feature: BookFeature,
    profile: UserPreferenceProfile
  ) -> Double {
    let rootCategory = BookFeature.categoryRoot(from: feature.categoryName)
    var matchedDates: [Date] = []

    if profile.preferredAuthors[feature.author] != nil,
       let date = profile.preferredAuthorDates[feature.author] {
      matchedDates.append(date)
    }

    if !feature.categoryName.isEmpty,
       profile.preferredCategories[feature.categoryName] != nil,
       let date = profile.preferredCategoryDates[feature.categoryName] {
      matchedDates.append(date)
    }

    if !rootCategory.isEmpty,
       profile.preferredCategories[rootCategory] != nil,
       let date = profile.preferredCategoryDates[rootCategory] {
      matchedDates.append(date)
    }

    for keyword in feature.keywords where profile.preferredKeywords[keyword] != nil {
      if let date = profile.preferredKeywordDates[keyword] {
        matchedDates.append(date)
      }
    }

    guard let latestMatchedDate = matchedDates.max() else {
      return 0
    }

    let ageInDays = max(0, now().timeIntervalSince(latestMatchedDate) / 86_400)
    return (1 - min(ageInDays / 180, 1)).clamped(to: 0...1)
  }

  private func publicationAgeScore(year: Int?) -> Double {
    guard let year else {
      return 0
    }

    let calendarYear = Calendar(identifier: .gregorian).component(.year, from: now())
    let age = max(0, calendarYear - year)
    return (1 - min(Double(age) / 10, 1)).clamped(to: 0...1)
  }

  private func confidence(
    profile: UserPreferenceProfile,
    usedModel: Bool
  ) -> RecommendationConfidence {
    if !usedModel || profile.bookmarkCount < 2 {
      return .low
    }

    if profile.bookmarkCount < 5 {
      return .medium
    }

    return .high
  }

  private func modelBlendWeight(
    profile: UserPreferenceProfile,
    usedModel: Bool
  ) -> Double {
    guard usedModel else {
      return 0
    }

    switch profile.bookmarkCount {
    case 0:
      return 0
    case 1...2:
      return 0.35
    case 3...4:
      return 0.50
    default:
      return 0.60
    }
  }

  private func reasons(
    input: RecommendationModelInput,
    feature: BookFeature,
    profile: UserPreferenceProfile
  ) -> [String] {
    guard profile.bookmarkCount > 0 else {
      return ["북마크가 쌓이면 추천 정확도가 높아져요"]
    }

    var reasons: [String] = []

    if input.authorAffinity > 0 {
      reasons.append("저장한 책과 같은 저자의 도서예요")
    }

    if input.keywordSimilarity > 0 {
      reasons.append("최근 높게 평가한 책과 주제가 비슷해요")
    }

    if input.categoryAffinity > 0 {
      reasons.append("최근 저장한 책과 같은 분야예요")
    }

    if input.trendOrRelatedSignal > 0 {
      reasons.append("함께 읽기 좋은 도서와 연결돼 있어요")
    }

    if profile.dislikedAuthors.contains(feature.author)
      || !feature.keywords.isDisjoint(with: profile.dislikedKeywords)
      || matchesDislikedCategory(feature: feature, profile: profile) {
      reasons.append("낮게 평가한 책과 겹치는 요소가 있어 점수를 낮췄어요")
    }

    if reasons.isEmpty {
      reasons.append("정보가 더 쌓이면 추천 정확도가 높아져요")
    }

    return reasons
  }
}

private extension Optional where Wrapped == Double {
  func clamped(maximum: Double) -> Double {
    switch self {
    case .some(let value):
      return value.clamped(to: 0...maximum)
    case .none:
      return 0
    }
  }
}
