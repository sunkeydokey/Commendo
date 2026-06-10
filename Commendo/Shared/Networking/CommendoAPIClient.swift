//
//  CommendoAPIClient.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import Foundation

struct CommendoAPIClient: Sendable {
  private let baseURL: URL

  init(baseURL: URL) {
    self.baseURL = baseURL
  }

  init(configuration: AppConfiguration) {
    self.init(baseURL: configuration.apiBaseURL)
  }

  func url(path: String, queryItems: [URLQueryItem]) throws -> URL {
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
