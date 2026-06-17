//
//  BookDetail.swift
//  Commendo
//
//  Created by Codex on 6/11/26.
//

import Foundation

struct BookDetailResponse: Decodable, Equatable, Sendable {
  let item: BookDetail
}

struct BookDetail: Decodable, Equatable, Sendable {
  let title: String
  let author: String
  let publisher: String
  let publishedDate: String
  let isbn: String
  let isbn13: String
  let coverURL: URL?
  let categoryId: Int
  let categoryName: String
  let description: String
  let fullDescription: String
  let priceStandard: Int
  let priceSales: Int
  let link: URL?
  let customerReviewRank: Int
  let itemPage: Int
  let tableOfContents: String
  let story: String
  let relatedBooks: [RelatedBook]

  var summary: BookSummary {
    BookSummary(
      isbn: BookIdentifier.isbn13(isbn13) ?? "",
      title: title,
      author: author,
      publisher: publisher,
      publishedDate: publishedDate,
      description: fullDescription.isEmpty ? description : fullDescription,
      coverURL: coverURL
    )
  }
}

struct RelatedBook: Decodable, Equatable, Sendable {
  let title: String
  let authors: String
  let publisher: String
  let publicationYear: String
  let isbn13: String
  let coverURL: URL?
  let detailURL: URL?

  var summary: BookSummary {
    BookSummary(
      isbn: BookIdentifier.isbn13(isbn13) ?? "",
      title: title,
      author: authors,
      publisher: publisher,
      publishedDate: publicationYear,
      description: "",
      coverURL: coverURL
    )
  }
}
