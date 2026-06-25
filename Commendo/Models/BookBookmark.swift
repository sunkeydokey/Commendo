//
//  BookBookmark.swift
//  Commendo
//
//  Created by Codex on 6/24/26.
//

import Foundation
import SwiftData

@Model
final class BookBookmark {
  @Attribute(.unique) var bookID: String
  var isbn13: String?
  var title: String
  var author: String
  var publisher: String
  var publishedDate: String
  var bookDescription: String
  var coverURLString: String?
  var rating: Double
  var review: String?
  var createdAt: Date
  var updatedAt: Date

  var summary: BookSummary {
    BookSummary(
      isbn: isbn13 ?? "",
      title: title,
      author: author,
      publisher: publisher,
      publishedDate: publishedDate,
      description: bookDescription,
      coverURL: coverURL
    )
  }

  init(
    book: BookSummary,
    bookID: String? = nil,
    rating: Double,
    review: String?,
    now: Date = Date()
  ) {
    self.bookID = bookID ?? book.id
    isbn13 = BookIdentifier.isbn13(book.isbn)
    title = book.title
    author = book.author
    publisher = book.publisher
    publishedDate = book.publishedDate
    bookDescription = book.description
    coverURLString = book.coverURL?.absoluteString
    self.rating = rating
    self.review = Self.normalizedReview(review)
    createdAt = now
    updatedAt = now
  }

  func update(
    from book: BookSummary,
    rating: Double,
    review: String?,
    now: Date = Date()
  ) {
    isbn13 = BookIdentifier.isbn13(book.isbn)
    title = book.title
    author = book.author
    publisher = book.publisher
    publishedDate = book.publishedDate
    bookDescription = book.description
    coverURLString = book.coverURL?.absoluteString
    self.rating = rating
    self.review = Self.normalizedReview(review)
    updatedAt = now
  }

  static func isValidRating(_ rating: Double) -> Bool {
    guard (0.5...5.0).contains(rating) else {
      return false
    }

    return (rating * 2).rounded() == rating * 2
  }

  static func normalizedReview(_ review: String?) -> String? {
    guard let trimmed = review?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty else {
      return nil
    }

    return trimmed
  }

  private var coverURL: URL? {
    guard let coverURLString else {
      return nil
    }

    return URL(string: coverURLString)
  }
}
