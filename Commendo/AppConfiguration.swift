//
//  AppConfiguration.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import Foundation

struct AppConfiguration {
  let apiBaseURL: URL

  static func load(bundle: Bundle = .main) throws -> AppConfiguration {
    guard let value = bundle.object(forInfoDictionaryKey: "COMMENDO_API_BASE_URL") as? String,
          let url = URL(string: value),
          !value.isEmpty else {
      throw ConfigurationError.missingAPIBaseURL
    }

    return AppConfiguration(apiBaseURL: url)
  }
}

enum ConfigurationError: Error {
  case missingAPIBaseURL
}
