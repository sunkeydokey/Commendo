//
//  CommendoAPIClient+PopularLoans.swift
//  Commendo
//
//  Created by Codex on 6/10/26.
//

import Foundation

extension CommendoAPIClient {
  func popularLoans(page: Int = 1, pageSize: Int = 20) async throws -> PopularLoanBookPage {
    let url = try url(
      path: "/books/trending",
      queryItems: [
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
    return try decoder.decode(PopularLoanBookPage.self, from: data)
  }
}
