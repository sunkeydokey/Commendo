//
//  CommendoAPIClient+Search.swift
//  Commendo
//
//  Created by Codex on 6/17/26.
//

import Foundation

extension CommendoAPIClient {
  func searchBooks(
    query: String,
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> BookSearchPage {
    let url = try url(
      path: "/books/search",
      queryItems: [
        URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "page", value: String(page)),
        URLQueryItem(name: "pageSize", value: String(pageSize)),
      ]
    )

    let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          200..<300 ~= httpResponse.statusCode else {
      throw CommendoAPIError.invalidResponse
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(BookSearchPage.self, from: data)
  }
}
