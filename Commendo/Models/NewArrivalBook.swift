//
//  NewArrivalBook.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import Foundation

enum NewArrivalListType: String, CaseIterable, Decodable, Hashable, Sendable {
  case all
  case special

  var title: String {
    switch self {
    case .all:
      "신간"
    case .special:
      "화제 신간"
    }
  }

  var sectionTitle: String {
    switch self {
    case .all:
      "신간 도서"
    case .special:
      "화제 신간"
    }
  }
}

struct NewArrivalBook: Decodable, Identifiable, Equatable, Sendable {
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
    if !isbn13.isEmpty {
      return isbn13
    }

    if !isbn.isEmpty {
      return isbn
    }

    return "\(title)-\(author)-\(publisher)"
  }
}

struct NewArrivalBookPage: Decodable, Equatable, Sendable {
  let type: NewArrivalListType
  let page: Int
  let pageSize: Int
  let totalResults: Int
  let snapshotDate: String
  let fetchedAt: Date
  let items: [NewArrivalBook]
}
