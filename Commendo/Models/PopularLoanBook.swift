//
//  PopularLoanBook.swift
//  Commendo
//
//  Created by Codex on 6/10/26.
//

import Foundation

struct PopularLoanBook: Decodable, Identifiable, Equatable, Sendable {
  let rank: Int
  let title: String
  let authors: String
  let publisher: String
  let publicationYear: String
  let isbn13: String
  let coverURL: URL?
  let detailURL: URL?
  let loanCount: Int

  var id: String {
    BookIdentifier.isbn13(isbn13) ?? "\(rank)-\(title)-\(authors)"
  }
}

struct PopularLoanBookPage: Decodable, Equatable, Sendable {
  let page: Int
  let pageSize: Int
  let totalResults: Int
  let periodStart: String
  let periodEnd: String
  let fetchedAt: Date
  let items: [PopularLoanBook]
}
