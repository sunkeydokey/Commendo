//
//  CommendoAPIClient+NewArrivals.swift
//  Commendo
//
//  Created by Codex on 6/10/26.
//

import Foundation

extension CommendoAPIClient {
  func newArrivals(
    type: NewArrivalListType,
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> NewArrivalBookPage {
    let url = try url(
      path: "/books/new-arrivals",
      queryItems: [
        URLQueryItem(name: "type", value: type.rawValue),
        URLQueryItem(name: "page", value: String(page)),
        URLQueryItem(name: "pageSize", value: String(pageSize)),
      ]
    )

    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse,
          200..<300 ~= httpResponse.statusCode else {
      throw CommendoAPIError.invalidResponse
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(NewArrivalBookPage.self, from: data)
  }
}
