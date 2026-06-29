//
//  RecommendationTypes.swift
//  Commendo
//
//  Created by Codex on 6/25/26.
//

import Foundation

struct BookFeature: Equatable {
  let isbn: String
  let title: String
  let author: String
  let publisher: String
  let categoryName: String
  let keywords: Set<String>
  let publicationYear: Int?
  let trendSignal: Double
  let newArrivalSignal: Double
  let relatedBookSignal: Double
  let searchResultSignal: Double
  let trendOrRelatedSignal: Double

  init(
    book: BookSummary,
    detail: BookDetail? = nil,
    sourceContext: RecommendationSourceContext = .none
  ) {
    isbn = BookIdentifier.isbn13(detail?.isbn13 ?? book.isbn) ?? book.isbn
    title = detail?.title ?? book.title
    author = detail?.author ?? book.author
    publisher = detail?.publisher ?? book.publisher
    categoryName = detail?.categoryName ?? ""
    publicationYear = Self.publicationYear(from: detail?.publishedDate ?? book.publishedDate)
    trendSignal = sourceContext.trendSignal
    newArrivalSignal = sourceContext.newArrivalSignal
    relatedBookSignal = max(
      sourceContext.relatedBookSignal,
      detail?.relatedBooks.isEmpty == false ? RecommendationSourceContext.relatedBook.relatedBookSignal : 0
    )
    searchResultSignal = sourceContext.searchResultSignal
    trendOrRelatedSignal = max(trendSignal, newArrivalSignal, relatedBookSignal, searchResultSignal)

    let keywordSource = [
      title,
      author,
      publisher,
      categoryName,
      detail?.description ?? book.description,
      detail?.fullDescription ?? "",
    ].joined(separator: " ")
    keywords = Self.keywords(from: keywordSource)
  }

  static func keywords(from text: String) -> Set<String> {
    let separators = CharacterSet.alphanumerics
      .union(CharacterSet(charactersIn: "가-힣"))
      .inverted

    return Set(
      text
        .lowercased()
        .components(separatedBy: separators)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.count >= 2 }
    )
  }

  static func categoryRoot(from categoryName: String) -> String {
    let parts = categoryName
      .components(separatedBy: CharacterSet(charactersIn: ">/"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    return parts.prefix(2).joined(separator: ">")
  }

  private static func publicationYear(from text: String) -> Int? {
    let digits = text.prefix(4)
    guard digits.count == 4 else {
      return nil
    }

    return Int(digits)
  }
}

enum RecommendationSourceContext: Hashable {
  case none
  case trend
  case newArrival
  case relatedBook
  case searchResult

  var trendSignal: Double {
    self == .trend ? 0.15 : 0
  }

  var newArrivalSignal: Double {
    self == .newArrival ? 0.12 : 0
  }

  var relatedBookSignal: Double {
    self == .relatedBook ? 0.20 : 0
  }

  var searchResultSignal: Double {
    self == .searchResult ? 0.08 : 0
  }

  var aggregateSignal: Double {
    max(trendSignal, newArrivalSignal, relatedBookSignal, searchResultSignal)
  }
}

struct UserPreferenceProfile: Equatable {
  let bookmarkCount: Int
  let preferredAuthors: [String: Double]
  let preferredCategories: [String: Double]
  let preferredKeywords: [String: Double]
  let preferredAuthorDates: [String: Date]
  let preferredCategoryDates: [String: Date]
  let preferredKeywordDates: [String: Date]
  let dislikedAuthors: Set<String>
  let dislikedCategories: Set<String>
  let dislikedKeywords: Set<String>

  init(bookmarks: [BookBookmark], now: Date = Date()) {
    bookmarkCount = bookmarks.count

    var authors: [String: Double] = [:]
    var categories: [String: Double] = [:]
    var keywords: [String: Double] = [:]
    var authorDates: [String: Date] = [:]
    var categoryDates: [String: Date] = [:]
    var keywordDates: [String: Date] = [:]
    var dislikedAuthors: Set<String> = []
    var dislikedCategories: Set<String> = []
    var dislikedKeywords: Set<String> = []

    for bookmark in bookmarks {
      let weight = Self.weight(for: bookmark, now: now)
      let categoryName = bookmark.categoryName ?? ""
      let categoryRoot = BookFeature.categoryRoot(from: categoryName)
      let keywordSet = BookFeature.keywords(
        from: [
          bookmark.title,
          bookmark.author,
          bookmark.publisher,
          categoryName,
          bookmark.bookDescription,
        ].joined(separator: " ")
      )

      if bookmark.rating >= 3 {
        authors[bookmark.author, default: 0] += weight
        Self.record(bookmark.updatedAt, for: bookmark.author, in: &authorDates)
        if !categoryName.isEmpty {
          categories[categoryName, default: 0] += weight
          Self.record(bookmark.updatedAt, for: categoryName, in: &categoryDates)
        }
        if !categoryRoot.isEmpty, categoryRoot != categoryName {
          categories[categoryRoot, default: 0] += weight * 0.8
          Self.record(bookmark.updatedAt, for: categoryRoot, in: &categoryDates)
        }
        for keyword in keywordSet {
          keywords[keyword, default: 0] += weight
          Self.record(bookmark.updatedAt, for: keyword, in: &keywordDates)
        }
      } else {
        dislikedAuthors.insert(bookmark.author)
        if !categoryName.isEmpty {
          dislikedCategories.insert(categoryName)
        }
        if !categoryRoot.isEmpty {
          dislikedCategories.insert(categoryRoot)
        }
        dislikedKeywords.formUnion(keywordSet)
      }
    }

    preferredAuthors = authors
    preferredCategories = categories
    preferredKeywords = keywords
    preferredAuthorDates = authorDates
    preferredCategoryDates = categoryDates
    preferredKeywordDates = keywordDates
    self.dislikedAuthors = dislikedAuthors
    self.dislikedCategories = dislikedCategories
    self.dislikedKeywords = dislikedKeywords
  }

  var hasEnoughBookmarksForModel: Bool {
    bookmarkCount >= 1
  }

  private static func weight(for bookmark: BookBookmark, now: Date) -> Double {
    let ratingWeight = max(0, (bookmark.rating - 2.5) / 2.5)
    let ageInDays = max(0, now.timeIntervalSince(bookmark.updatedAt) / 86_400)
    let recencyWeight = max(0.25, 1 - min(ageInDays / 180, 0.75))
    return ratingWeight * recencyWeight
  }

  private static func record(_ date: Date, for key: String, in dates: inout [String: Date]) {
    guard !key.isEmpty else {
      return
    }

    if let current = dates[key], current >= date {
      return
    }

    dates[key] = date
  }
}

enum RecommendationConfidence: String, Equatable {
  case low
  case medium
  case high
}

struct RecommendationResult: Equatable {
  let score: Int
  let confidence: RecommendationConfidence
  let reasons: [String]
  let disclaimer: String

  init(
    score: Int,
    confidence: RecommendationConfidence,
    reasons: [String],
    disclaimer: String = "머신러닝 기반 추정값이며 실제 만족도를 보장하지 않습니다."
  ) {
    self.score = min(100, max(0, score))
    self.confidence = confidence
    self.reasons = Array(reasons.prefix(2))
    self.disclaimer = disclaimer
  }
}

struct RecommendationModelInput: Equatable {
  let categoryAffinity: Double
  let keywordSimilarity: Double
  let authorAffinity: Double
  let ratingAffinity: Double
  let recencyScore: Double
  let publicationAge: Double
  let trendOrRelatedSignal: Double
}

extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
