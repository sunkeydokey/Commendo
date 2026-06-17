//
//  BookIdentifier.swift
//  Commendo
//
//  Created by Codex on 6/17/26.
//

enum BookIdentifier {
  static func isbn13(_ value: String) -> String? {
    guard value.count == 13, value.allSatisfy(\.isNumber) else {
      return nil
    }

    return value
  }
}
