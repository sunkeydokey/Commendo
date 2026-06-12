//
//  CommendoAPIClient+BookDetail.swift
//  Commendo
//
//  Created by Codex on 6/11/26.
//

import Foundation

extension CommendoAPIClient {
  func bookDetail(isbn: String) async throws -> BookDetailResponse {
    let url = try url(
      path: "/books/detail",
      queryItems: [URLQueryItem(name: "isbn", value: isbn)]
    )

    let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          200..<300 ~= httpResponse.statusCode else {
      throw CommendoAPIError.invalidResponse
    }

    return try JSONDecoder().decode(BookDetailResponse.self, from: data)
  }
}
