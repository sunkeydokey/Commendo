//
//  BookSearchResult.swift
//  Commendo
//
//  Created by Codex on 6/17/26.
//

import Foundation

struct BookSearchResult: Decodable, Identifiable, Equatable, Sendable {
  let title: String
  let author: String
  let publisher: String
  let publishedDate: String
  let isbn: String
  let isbn13: String
  let coverURL: URL?
  let categoryName: String
  let description: String
  let priceStandard: Int
  let priceSales: Int
  let link: URL?

  var id: String {
    BookIdentifier.isbn13(isbn13) ?? "\(title)-\(author)-\(publisher)"
  }
}

struct BookSearchPage: Decodable, Equatable, Sendable {
  let query: String
  let page: Int
  let pageSize: Int
  let totalResults: Int
  let fetchedAt: Date
  let items: [BookSearchResult]
}
