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

  var summary: BookSummary {
    BookSummary(
      isbn: isbn13.isEmpty ? isbn : isbn13,
      title: title,
      author: author,
      publisher: publisher,
      publishedDate: publishedDate,
      description: fullDescription.isEmpty ? description : fullDescription,
      coverURL: coverURL
    )
  }
}
