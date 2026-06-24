//
//  BookDetail.swift
//  Commendo
//
//  Created by Codex on 6/11/26.
//

import Foundation

struct BookDetailResponse: Decodable, Equatable, Sendable {
  let item: BookDetail
}

struct BookDetail: Decodable, Equatable, Sendable {
  let title: String
  let author: String
  let publisher: String
  let publishedDate: String
  let isbn: String
  let isbn13: String
  let coverURL: URL?
  let categoryId: Int
  let categoryName: String
  let description: String
  let fullDescription: String
  let priceStandard: Int
  let priceSales: Int
  let link: URL?
  let customerReviewRank: Int
  let itemPage: Int
  let tableOfContents: String
  let story: String
  let relatedBooks: [RelatedBook]

  var summary: BookSummary {
    BookSummary(
      isbn: BookIdentifier.isbn13(isbn13) ?? "",
      title: title,
      author: author,
      publisher: publisher,
      publishedDate: publishedDate,
      description: fullDescription.isEmpty ? description : fullDescription,
      coverURL: coverURL
    )
  }
}

struct RelatedBook: Decodable, Equatable, Sendable {
  let title: String
  let authors: String
  let publisher: String
  let publicationYear: String
  let isbn13: String
  let coverURL: URL?
  let detailURL: URL?

  enum CodingKeys: String, CodingKey {
    case title
    case authors
    case publisher
    case publicationYear
    case isbn13
    case coverURL
    case detailURL
  }

  init(
    title: String,
    authors: String,
    publisher: String,
    publicationYear: String,
    isbn13: String,
    coverURL: URL?,
    detailURL: URL?
  ) {
    self.title = title
    self.authors = authors
    self.publisher = publisher
    self.publicationYear = publicationYear
    self.isbn13 = isbn13
    self.coverURL = coverURL
    self.detailURL = detailURL
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    title = try container.decode(String.self, forKey: .title)
    authors = try container.decode(String.self, forKey: .authors)
    publisher = try container.decode(String.self, forKey: .publisher)
    publicationYear = try container.decode(String.self, forKey: .publicationYear)
    isbn13 = try container.decode(String.self, forKey: .isbn13)
    coverURL = Self.decodeURL(forKey: .coverURL, from: container)
    detailURL = Self.decodeURL(forKey: .detailURL, from: container)
  }

  var summary: BookSummary {
    BookSummary(
      isbn: BookIdentifier.isbn13(isbn13) ?? "",
      title: title,
      author: authors,
      publisher: publisher,
      publishedDate: publicationYear,
      description: "",
      coverURL: coverURL
    )
  }

  private static func decodeURL(
    forKey key: CodingKeys,
    from container: KeyedDecodingContainer<CodingKeys>
  ) -> URL? {
    guard let value = try? container.decodeIfPresent(String.self, forKey: key),
          !value.isEmpty else {
      return nil
    }

    return URL(string: value)
  }
}
