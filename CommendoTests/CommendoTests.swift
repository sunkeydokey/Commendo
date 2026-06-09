//
//  CommendoTests.swift
//  CommendoTests
//
//  Created by 이선기 on 6/8/26.
//

import Foundation
import Testing
@testable import Commendo

struct CommendoTests {
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
}
