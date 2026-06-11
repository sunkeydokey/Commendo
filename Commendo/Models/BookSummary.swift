//
//  BookSummary.swift
//  Commendo
//
//  Created by Codex on 6/10/26.
//

import Foundation

struct BookSummary: Identifiable, Hashable {
  let isbn: String
  let title: String
  let author: String
  let publisher: String
  let publishedDate: String
  let description: String
  let coverURL: URL?

  var id: String {
    isbn.isEmpty ? "\(title)-\(author)-\(publisher)" : isbn
  }
}

extension NewArrivalBook {
  var summary: BookSummary {
    BookSummary(
      isbn: isbn13.isEmpty ? isbn : isbn13,
      title: title,
      author: author,
      publisher: publisher,
      publishedDate: publishedDate,
      description: description,
      coverURL: coverURL
    )
  }
}

extension PopularLoanBook {
  var summary: BookSummary {
    BookSummary(
      isbn: isbn13,
      title: title,
      author: authors,
      publisher: publisher,
      publishedDate: publicationYear,
      description: "",
      coverURL: coverURL
    )
  }
}
