//
//  CommendoAPIClient.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import Foundation

struct CommendoAPIClient: Sendable {
  let baseURL: URL

  init(baseURL: URL) {
    self.baseURL = baseURL
  }

  init(configuration: AppConfiguration) {
    self.init(baseURL: configuration.apiBaseURL)
  }

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

  private func url(path: String, queryItems: [URLQueryItem]) throws -> URL {
    guard var components = URLComponents(
      url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
      resolvingAgainstBaseURL: false
    ) else {
      throw CommendoAPIError.invalidURL
    }

    components.queryItems = queryItems

    guard let url = components.url else {
      throw CommendoAPIError.invalidURL
    }

    return url
  }
}

enum CommendoAPIError: Error {
  case invalidURL
  case invalidResponse
}
