//
//  CommendoTests.swift
//  CommendoTests
//
//  Created by 이선기 on 6/8/26.
//

import Foundation
import SwiftUI
import Testing
@testable import Commendo

struct CommendoTests {
  @MainActor
  @Test func mapsNewArrivalBookToSummary() {
    let book = NewArrivalBook(
      title: "테스트 신간",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026-06-10",
      isbn: "1234567890",
      isbn13: "9791234567890",
      coverURL: URL(string: "https://example.com/new.jpg"),
      categoryName: "국내도서",
      description: "설명",
      priceStandard: 18_000,
      priceSales: 16_200,
      link: nil
    )

    #expect(book.summary.id == "9791234567890")
    #expect(book.summary.author == "작가")
    #expect(book.summary.description == "설명")
  }

  @MainActor
  @Test func mapsPopularLoanBookToSummary() {
    let book = PopularLoanBook(
      rank: 1,
      title: "테스트 인기 도서",
      authors: "작가",
      publisher: "출판사",
      publicationYear: "2026",
      isbn13: "9791234567890",
      coverURL: URL(string: "https://example.com/popular.jpg"),
      detailURL: nil,
      loanCount: 42
    )

    #expect(book.summary.id == "9791234567890")
    #expect(book.summary.author == "작가")
    #expect(book.summary.publishedDate == "2026")
  }

  @MainActor
  @Test func trendCoordinatorManagesBookDetailRoutes() {
    let coordinator = TrendCoordinator()
    let firstBook = BookSummary(
      isbn: "1",
      title: "첫 번째 책",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026",
      description: "설명",
      coverURL: nil
    )
    let relatedBook = BookSummary(
      isbn: "2",
      title: "연관 도서",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026",
      description: "설명",
      coverURL: nil
    )

    coordinator.showBookDetail(firstBook)
    #expect(coordinator.path.count == 1)

    coordinator.showRelatedBook(relatedBook)
    #expect(coordinator.path.count == 2)

    coordinator.pop()
    #expect(coordinator.path.count == 1)

    coordinator.showAvailability(firstBook)
    #expect(coordinator.path.count == 2)
  }

  @MainActor
  @Test func decodesNewArrivalBookPage() throws {
    let json = """
    {
      "type": "special",
      "page": 1,
      "pageSize": 20,
      "totalResults": 1,
      "snapshotDate": "2026-06-09",
      "fetchedAt": "2026-06-09T10:00:00.000Z",
      "items": [
        {
          "title": "테스트 신간",
          "author": "작가",
          "publisher": "출판사",
          "publishedDate": "2026-06-09",
          "isbn": "1234567890",
          "isbn13": "9791234567890",
          "coverURL": "https://example.com/cover.jpg",
          "categoryName": "국내도서",
          "description": "설명",
          "priceStandard": 18000,
          "priceSales": 16200,
          "link": "https://example.com/book"
        }
      ]
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let page = try decoder.decode(NewArrivalBookPage.self, from: json)

    #expect(page.type == .special)
    #expect(page.items.first?.id == "9791234567890")
    #expect(page.items.first?.coverURL?.absoluteString == "https://example.com/cover.jpg")
  }

  @MainActor
  @Test func decodesPopularLoanBookPage() throws {
    let json = """
    {
      "page": 1,
      "pageSize": 20,
      "totalResults": 1,
      "periodStart": "2026-06-04",
      "periodEnd": "2026-06-10",
      "fetchedAt": "2026-06-10T00:00:00.000Z",
      "items": [
        {
          "rank": 1,
          "title": "테스트 인기 도서",
          "authors": "작가",
          "publisher": "출판사",
          "publicationYear": "2026",
          "isbn13": "9791234567890",
          "coverURL": "https://example.com/popular.jpg",
          "detailURL": "https://example.com/books/1",
          "loanCount": 42
        }
      ]
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let page = try decoder.decode(PopularLoanBookPage.self, from: json)

    #expect(page.periodStart == "2026-06-04")
    #expect(page.items.first?.rank == 1)
    #expect(page.items.first?.loanCount == 42)
    #expect(page.items.first?.coverURL?.absoluteString == "https://example.com/popular.jpg")
  }
}
