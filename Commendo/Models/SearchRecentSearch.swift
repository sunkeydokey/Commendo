//
//  SearchRecentSearch.swift
//  Commendo
//
//  Created by Codex on 6/29/26.
//

import Foundation
import SwiftData

@Model
final class SearchRecentSearch {
  static let displayLimit = 4

  @Attribute(.unique) var normalizedText: String
  var createdAt: Date
  var updatedAt: Date

  init(normalizedText: String, now: Date = Date()) {
    self.normalizedText = normalizedText
    createdAt = now
    updatedAt = now
  }

  func markUpdated(now: Date = Date()) {
    updatedAt = now
  }

  @discardableResult
  static func upsert(
    normalizedText: String,
    in modelContext: ModelContext,
    now: Date = Date()
  ) throws -> SearchRecentSearch {
    var descriptor = FetchDescriptor<SearchRecentSearch>(
      predicate: #Predicate<SearchRecentSearch> { recentSearch in
        recentSearch.normalizedText == normalizedText
      }
    )
    descriptor.fetchLimit = 1

    if let existingRecentSearch = try modelContext.fetch(descriptor).first {
      existingRecentSearch.markUpdated(now: now)
      return existingRecentSearch
    }

    let recentSearch = SearchRecentSearch(normalizedText: normalizedText, now: now)
    modelContext.insert(recentSearch)
    return recentSearch
  }

  static func displayTexts(from recentSearches: [SearchRecentSearch]) -> [String] {
    Array(recentSearches.prefix(displayLimit).map(\.normalizedText))
  }
}

enum SearchCommit {
  static func normalizedValue(from value: String) -> String? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return (2...50).contains(normalized.count) ? normalized : nil
  }
}
