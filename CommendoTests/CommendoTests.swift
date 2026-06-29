//
//  CommendoTests.swift
//  CommendoTests
//
//  Created by 이선기 on 6/8/26.
//

import Foundation
import SwiftUI
import Testing
@testable import Commendo

struct CommendoTests {
  @MainActor
  @Test func mapsNewArrivalBookToSummary() {
    let book = NewArrivalBook(
      title: "테스트 신간",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026-06-10",
      isbn: "1234567890",
      isbn13: "9791234567890",
      coverURL: URL(string: "https://example.com/new.jpg"),
      categoryName: "국내도서",
      description: "설명",
      priceStandard: 18_000,
      priceSales: 16_200,
      link: nil
    )

    #expect(book.summary.id == "9791234567890")
    #expect(book.summary.author == "작가")
    #expect(book.summary.description == "설명")
  }

  @MainActor
  @Test func mapsPopularLoanBookToSummary() {
    let book = PopularLoanBook(
      rank: 1,
      title: "테스트 인기 도서",
      authors: "작가",
      publisher: "출판사",
      publicationYear: "2026",
      isbn13: "9791234567890",
      coverURL: URL(string: "https://example.com/popular.jpg"),
      detailURL: nil,
      loanCount: 42
    )

    #expect(book.summary.id == "9791234567890")
    #expect(book.summary.author == "작가")
    #expect(book.summary.publishedDate == "2026")
  }

  @MainActor
  @Test func mapsBookSearchResultToSummary() {
    let book = BookSearchResult(
      title: "검색 도서",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026-06-17",
      isbn: "1234567890",
      isbn13: "9791234567890",
      coverURL: URL(string: "https://example.com/search.jpg"),
      categoryName: "국내도서",
      description: "검색 설명",
      priceStandard: 18_000,
      priceSales: 16_200,
      link: nil
    )

    #expect(book.summary.id == "9791234567890")
    #expect(book.summary.title == "검색 도서")
    #expect(book.summary.author == "작가")
    #expect(book.summary.description == "검색 설명")
  }

  @MainActor
  @Test func usesOnlyISBN13AsBookIdentifier() {
    let summary = BookSummary(
      isbn: "1234567890",
      title: "10자리 ISBN 도서",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026",
      description: "설명",
      coverURL: nil
    )
    let searchResult = BookSearchResult(
      title: "알라딘 내부 ID 도서",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026",
      isbn: "K092138437",
      isbn13: "",
      coverURL: nil,
      categoryName: "국내도서",
      description: "설명",
      priceStandard: 0,
      priceSales: 0,
      link: nil
    )
    let newArrival = NewArrivalBook(
      title: "신간",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026",
      isbn: "1234567890",
      isbn13: "",
      coverURL: nil,
      categoryName: "국내도서",
      description: "설명",
      priceStandard: 0,
      priceSales: 0,
      link: nil
    )

    #expect(BookIdentifier.isbn13("9791234567890") == "9791234567890")
    #expect(BookIdentifier.isbn13("1234567890") == nil)
    #expect(BookIdentifier.isbn13("K092138437") == nil)
    #expect(summary.id == "10자리 ISBN 도서-작가-출판사")
    #expect(searchResult.id == "알라딘 내부 ID 도서-작가-출판사")
    #expect(searchResult.summary.isbn.isEmpty)
    #expect(newArrival.id == "신간-작가-출판사")
    #expect(newArrival.summary.isbn.isEmpty)
  }

  @MainActor
  @Test func mapsBookSummaryToBookmark() {
    let book = BookSummary(
      isbn: "9791234567890",
      title: "저장 도서",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026",
      description: "설명",
      coverURL: URL(string: "https://example.com/book.jpg")
    )
    let now = Date(timeIntervalSince1970: 100)

    let bookmark = BookBookmark(
      book: book,
      categoryName: "국내도서>인문>철학",
      rating: 4.5,
      review: "  좋은 책  ",
      now: now
    )

    #expect(bookmark.bookID == "9791234567890")
    #expect(bookmark.isbn13 == "9791234567890")
    #expect(bookmark.title == "저장 도서")
    #expect(bookmark.author == "작가")
    #expect(bookmark.publisher == "출판사")
    #expect(bookmark.categoryName == "국내도서>인문>철학")
    #expect(bookmark.publishedDate == "2026")
    #expect(bookmark.bookDescription == "설명")
    #expect(bookmark.coverURLString == "https://example.com/book.jpg")
    #expect(bookmark.rating == 4.5)
    #expect(bookmark.review == "좋은 책")
    #expect(bookmark.createdAt == now)
    #expect(bookmark.updatedAt == now)
    #expect(bookmark.summary.id == "9791234567890")
    #expect(bookmark.summary.coverURL == URL(string: "https://example.com/book.jpg"))
  }

  @Test func validatesBookmarkRating() {
    #expect(BookBookmark.isValidRating(0.5))
    #expect(BookBookmark.isValidRating(3.5))
    #expect(BookBookmark.isValidRating(5.0))
    #expect(!BookBookmark.isValidRating(0))
    #expect(!BookBookmark.isValidRating(5.5))
    #expect(!BookBookmark.isValidRating(3.3))
  }

  @Test func normalizesBookmarkReview() {
    #expect(BookBookmark.normalizedReview("  좋았어요  ") == "좋았어요")
    #expect(BookBookmark.normalizedReview(" \n\t ") == nil)
    #expect(BookBookmark.normalizedReview(nil) == nil)
  }

  @Test func recommendationFallsBackForEmptyBookmarks() {
    let service = RecommendationScoringService(ranker: FixedRecommendationRanker(score: nil)) {
      Date(timeIntervalSince1970: 1_767_225_600)
    }

    let result = service.score(book: Self.recommendationBook(), bookmarks: [])

    #expect((0...100).contains(result.score))
    #expect(result.confidence == .low)
    #expect(result.reasons == ["북마크가 쌓이면 추천 정확도가 높아져요"])
  }

  @Test func bookFeatureExtractsKoreanKeywords() {
    let keywords = BookFeature.keywords(from: "인문 철학 사유")

    #expect(keywords.contains("인문"))
    #expect(keywords.contains("철학"))
    #expect(keywords.contains("사유"))
  }

  @Test func recommendationIncreasesForMatchingHighRatedBookmark() {
    let now = Date(timeIntervalSince1970: 1_767_225_600)
    let service = RecommendationScoringService(ranker: nil) { now }
    let matchingBookmark = BookBookmark(
      book: Self.recommendationBook(author: "관심 작가", description: "인문 철학 사유"),
      rating: 5,
      review: nil,
      now: now
    )
    let unrelatedBookmark = BookBookmark(
      book: Self.recommendationBook(title: "다른 책", author: "다른 작가", description: "요리 여행"),
      rating: 5,
      review: nil,
      now: now
    )

    let matchingScore = service.score(
      book: Self.recommendationBook(author: "관심 작가", description: "인문 철학 사유"),
      bookmarks: [matchingBookmark]
    ).score
    let unrelatedScore = service.score(
      book: Self.recommendationBook(author: "관심 작가", description: "인문 철학 사유"),
      bookmarks: [unrelatedBookmark]
    ).score

    #expect(matchingScore > unrelatedScore)
  }

  @Test func recommendationUsesDetailCategoryAsLocalSignal() {
    let now = Date(timeIntervalSince1970: 1_767_225_600)
    let service = RecommendationScoringService(ranker: nil) { now }
    let bookmark = BookBookmark(
      book: Self.recommendationBook(author: "다른 작가", description: "철학 에세이"),
      rating: 5,
      review: nil,
      now: now
    )
    let candidate = Self.recommendationBook(author: "후보 작가", description: "새로운 책")

    let detailScore = service.score(
      book: candidate,
      detail: Self.recommendationDetail(categoryName: "인문 철학"),
      bookmarks: [bookmark]
    ).score
    let summaryOnlyScore = service.score(book: candidate, bookmarks: [bookmark]).score

    #expect(detailScore > summaryOnlyScore)
  }

  @Test func recommendationUsesBookmarkedCategoryPreference() {
    let now = Date(timeIntervalSince1970: 1_767_225_600)
    let service = RecommendationScoringService(ranker: nil) { now }
    let bookmark = BookBookmark(
      book: Self.recommendationBook(author: "다른 작가", description: "다른 설명"),
      categoryName: "국내도서>인문>철학",
      rating: 5,
      review: nil,
      now: now
    )
    let candidate = Self.recommendationBook(author: "후보 작가", description: "새로운 책")

    let matchingScore = service.score(
      book: candidate,
      detail: Self.recommendationDetail(categoryName: "국내도서>인문>철학"),
      bookmarks: [bookmark]
    ).score
    let unrelatedScore = service.score(
      book: candidate,
      detail: Self.recommendationDetail(categoryName: "국내도서>요리"),
      bookmarks: [bookmark]
    ).score

    #expect(matchingScore > unrelatedScore)
  }

  @Test func recommendationRecencyUsesLatestMatchedSignalDate() {
    let now = Date(timeIntervalSince1970: 1_767_225_600)
    let ranker = CapturingRecommendationRanker(score: nil)
    let service = RecommendationScoringService(ranker: ranker) { now }
    let oldMatchingBookmark = BookBookmark(
      book: BookSummary(
        isbn: "9790000000001",
        title: "오래된취향",
        author: "관심저자",
        publisher: "오래된출판",
        publishedDate: "2025",
        description: "오래된설명",
        coverURL: nil
      ),
      rating: 5,
      review: nil,
      now: now.addingTimeInterval(TimeInterval(-90 * 86_400))
    )
    let recentUnrelatedBookmark = BookBookmark(
      book: BookSummary(
        isbn: "9790000000002",
        title: "최신무관",
        author: "다른저자",
        publisher: "최신출판",
        publishedDate: "2026",
        description: "최신설명",
        coverURL: nil
      ),
      rating: 5,
      review: nil,
      now: now
    )
    let candidate = BookSummary(
      isbn: "9790000000003",
      title: "후보도서",
      author: "관심저자",
      publisher: "후보출판",
      publishedDate: "2026",
      description: "후보설명",
      coverURL: nil
    )

    _ = service.score(
      book: candidate,
      bookmarks: [oldMatchingBookmark, recentUnrelatedBookmark]
    )

    #expect(abs((ranker.inputs.last?.recencyScore ?? -1) - 0.5) < 0.0001)
  }

  @Test func bookFeatureSplitsSourceSignalsAndPreservesAggregate() {
    let book = Self.recommendationBook()
    let detailWithRelatedBooks = Self.recommendationDetail(
      categoryName: "국내도서>인문>철학",
      relatedBooks: [
        RelatedBook(
          title: "연관 도서",
          authors: "연관 작가",
          publisher: "연관 출판사",
          publicationYear: "2025",
          isbn13: "9790000000004",
          coverURL: nil,
          detailURL: nil
        ),
      ]
    )

    let detailRelatedFeature = BookFeature(book: book, detail: detailWithRelatedBooks)
    let trendFeature = BookFeature(book: book, sourceContext: .trend)
    let newArrivalFeature = BookFeature(book: book, sourceContext: .newArrival)
    let relatedBookFeature = BookFeature(book: book, sourceContext: .relatedBook)
    let searchResultFeature = BookFeature(book: book, sourceContext: .searchResult)

    #expect(detailRelatedFeature.relatedBookSignal == RecommendationSourceContext.relatedBook.relatedBookSignal)
    #expect(detailRelatedFeature.trendOrRelatedSignal == RecommendationSourceContext.relatedBook.aggregateSignal)
    #expect(trendFeature.trendSignal == RecommendationSourceContext.trend.trendSignal)
    #expect(trendFeature.trendOrRelatedSignal == RecommendationSourceContext.trend.aggregateSignal)
    #expect(newArrivalFeature.newArrivalSignal == RecommendationSourceContext.newArrival.newArrivalSignal)
    #expect(newArrivalFeature.trendOrRelatedSignal == RecommendationSourceContext.newArrival.aggregateSignal)
    #expect(relatedBookFeature.relatedBookSignal == RecommendationSourceContext.relatedBook.relatedBookSignal)
    #expect(relatedBookFeature.trendOrRelatedSignal == RecommendationSourceContext.relatedBook.aggregateSignal)
    #expect(searchResultFeature.searchResultSignal == RecommendationSourceContext.searchResult.searchResultSignal)
    #expect(searchResultFeature.trendOrRelatedSignal == RecommendationSourceContext.searchResult.aggregateSignal)
  }

  @Test func recommendationModelInputKeepsSourceAggregateFeature() {
    let now = Date(timeIntervalSince1970: 1_767_225_600)
    let ranker = CapturingRecommendationRanker(score: nil)
    let service = RecommendationScoringService(ranker: ranker) { now }
    let bookmark = BookBookmark(
      book: Self.recommendationBook(title: "저장 도서", author: "저장 작가", description: "저장 설명"),
      rating: 5,
      review: nil,
      now: now
    )

    _ = service.score(
      book: Self.recommendationBook(title: "검색 도서", author: "검색 작가", description: "검색 설명"),
      bookmarks: [bookmark],
      sourceContext: .searchResult
    )

    #expect(ranker.inputs.last?.trendOrRelatedSignal == RecommendationSourceContext.searchResult.aggregateSignal)
  }

  @Test func recommendationPenalizesOnlyLowRatedOverlap() {
    let now = Date(timeIntervalSince1970: 1_767_225_600)
    let service = RecommendationScoringService(ranker: nil) { now }
    let dislikedBookmark = BookBookmark(
      book: Self.recommendationBook(author: "낮은 평점 작가", description: "불호 주제"),
      rating: 1,
      review: nil,
      now: now
    )

    let result = service.score(
      book: Self.recommendationBook(author: "낮은 평점 작가", description: "불호 주제"),
      bookmarks: [dislikedBookmark]
    )

    #expect(result.score < 40)
    #expect(result.reasons.contains("낮게 평가한 책과 겹치는 요소가 있어 점수를 낮췄어요"))
  }

  @Test func recommendationPenalizesLowRatedCategoryOverlap() {
    let now = Date(timeIntervalSince1970: 1_767_225_600)
    let service = RecommendationScoringService(ranker: nil) { now }
    let dislikedBookmark = BookBookmark(
      book: Self.recommendationBook(author: "다른 작가", description: "다른 설명"),
      categoryName: "국내도서>공포",
      rating: 1,
      review: nil,
      now: now
    )

    let result = service.score(
      book: Self.recommendationBook(author: "후보 작가", description: "새로운 책"),
      detail: Self.recommendationDetail(categoryName: "국내도서>공포"),
      bookmarks: [dislikedBookmark]
    )

    #expect(result.score < 35)
    #expect(result.reasons.contains("낮게 평가한 책과 겹치는 요소가 있어 점수를 낮췄어요"))
  }

  @Test func recommendationUsesInjectedModelScoreWhenAvailable() {
    let now = Date(timeIntervalSince1970: 1_767_225_600)
    let service = RecommendationScoringService(ranker: FixedRecommendationRanker(score: 1)) { now }
    let bookmark = BookBookmark(
      book: Self.recommendationBook(author: "관심 작가", description: "인문 철학"),
      rating: 5,
      review: nil,
      now: now
    )

    let result = service.score(
      book: Self.recommendationBook(author: "관심 작가", description: "인문 철학"),
      bookmarks: [bookmark]
    )

    #expect(result.score > 80)
  }

  @Test func recommendationDoesNotLetOneBookmarkOverweightLowModelScore() {
    let now = Date(timeIntervalSince1970: 1_767_225_600)
    let service = RecommendationScoringService(ranker: FixedRecommendationRanker(score: 0)) { now }
    let bookmark = BookBookmark(
      book: Self.recommendationBook(author: "관심 작가", description: "인문 철학"),
      categoryName: "국내도서>인문>철학",
      rating: 5,
      review: nil,
      now: now
    )

    let result = service.score(
      book: Self.recommendationBook(author: "관심 작가", description: "인문 철학"),
      detail: Self.recommendationDetail(categoryName: "국내도서>인문>철학"),
      bookmarks: [bookmark]
    )

    #expect(result.score > 50)
  }

  @MainActor
  @Test func trendCoordinatorManagesBookDetailRoutes() {
    let coordinator = TrendCoordinator()
    let firstBook = BookSummary(
      isbn: "1",
      title: "첫 번째 책",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026",
      description: "설명",
      coverURL: nil
    )
    let relatedBook = BookSummary(
      isbn: "2",
      title: "연관 도서",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026",
      description: "설명",
      coverURL: nil
    )

    coordinator.showBookDetail(firstBook)
    #expect(coordinator.path.count == 1)

    coordinator.showRelatedBook(relatedBook)
    #expect(coordinator.path.count == 2)

    coordinator.pop()
    #expect(coordinator.path.count == 1)

    coordinator.showAvailability(firstBook)
    #expect(coordinator.path.count == 2)
  }

  @MainActor
  @Test func searchCoordinatorManagesBookDetailRoutes() {
    let coordinator = SearchCoordinator()
    let firstBook = BookSummary(
      isbn: "1",
      title: "검색 도서",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026",
      description: "설명",
      coverURL: nil
    )
    let relatedBook = BookSummary(
      isbn: "2",
      title: "연관 도서",
      author: "작가",
      publisher: "출판사",
      publishedDate: "2026",
      description: "설명",
      coverURL: nil
    )

    coordinator.showBookDetail(firstBook)
    #expect(coordinator.path.count == 1)

    coordinator.showRelatedBook(relatedBook)
    #expect(coordinator.path.count == 2)

    coordinator.pop()
    #expect(coordinator.path.count == 1)

    coordinator.showAvailability(firstBook)
    #expect(coordinator.path.count == 2)
  }

  @Test func normalizesCommittedSearchValues() {
    #expect(SearchCommit.normalizedValue(from: "  architecture  ") == "architecture")
    #expect(SearchCommit.normalizedValue(from: "\n\t") == nil)
    #expect(SearchCommit.normalizedValue(from: "a") == nil)
    #expect(SearchCommit.normalizedValue(from: String(repeating: "a", count: 51)) == nil)
    #expect(SearchCommit.normalizedValue(from: "mindful spaces") == SearchCommit.normalizedValue(from: " mindful spaces "))
  }

  @MainActor
  @Test func decodesNewArrivalBookPage() throws {
    let json = """
    {
      "type": "special",
      "page": 1,
      "pageSize": 20,
      "totalResults": 1,
      "snapshotDate": "2026-06-09",
      "fetchedAt": "2026-06-09T10:00:00.000Z",
      "items": [
        {
          "title": "테스트 신간",
          "author": "작가",
          "publisher": "출판사",
          "publishedDate": "2026-06-09",
          "isbn": "1234567890",
          "isbn13": "9791234567890",
          "coverURL": "https://example.com/cover.jpg",
          "categoryName": "국내도서",
          "description": "설명",
          "priceStandard": 18000,
          "priceSales": 16200,
          "link": "https://example.com/book"
        }
      ]
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let page = try decoder.decode(NewArrivalBookPage.self, from: json)

    #expect(page.type == .special)
    #expect(page.items.first?.id == "9791234567890")
    #expect(page.items.first?.coverURL?.absoluteString == "https://example.com/cover.jpg")
  }

  @MainActor
  @Test func decodesPopularLoanBookPage() throws {
    let json = """
    {
      "page": 1,
      "pageSize": 20,
      "totalResults": 1,
      "periodStart": "2026-06-04",
      "periodEnd": "2026-06-10",
      "fetchedAt": "2026-06-10T00:00:00.000Z",
      "items": [
        {
          "rank": 1,
          "title": "테스트 인기 도서",
          "authors": "작가",
          "publisher": "출판사",
          "publicationYear": "2026",
          "isbn13": "9791234567890",
          "coverURL": "https://example.com/popular.jpg",
          "detailURL": "https://example.com/books/1",
          "loanCount": 42
        }
      ]
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let page = try decoder.decode(PopularLoanBookPage.self, from: json)

    #expect(page.periodStart == "2026-06-04")
    #expect(page.items.first?.rank == 1)
    #expect(page.items.first?.loanCount == 42)
    #expect(page.items.first?.coverURL?.absoluteString == "https://example.com/popular.jpg")
  }

  @MainActor
  @Test func decodesBookSearchPage() throws {
    let json = """
    {
      "query": "architecture",
      "page": 1,
      "pageSize": 20,
      "totalResults": 1,
      "fetchedAt": "2026-06-17T00:00:00.000Z",
      "items": [
        {
          "title": "검색 도서",
          "author": "작가",
          "publisher": "출판사",
          "publishedDate": "2026-06-17",
          "isbn": "1234567890",
          "isbn13": "9791234567890",
          "coverURL": "https://example.com/search.jpg",
          "categoryName": "국내도서",
          "description": "설명",
          "priceStandard": 18000,
          "priceSales": 16200,
          "link": "https://example.com/book"
        }
      ]
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let page = try decoder.decode(BookSearchPage.self, from: json)

    #expect(page.query == "architecture")
    #expect(page.totalResults == 1)
    #expect(page.items.first?.id == "9791234567890")
    #expect(page.items.first?.coverURL?.absoluteString == "https://example.com/search.jpg")
  }

  @MainActor
  @Test func decodesBookDetailResponse() throws {
    let json = """
    {
      "item": {
        "title": "테스트 상세 도서",
        "author": "작가",
        "publisher": "출판사",
        "publishedDate": "2026-06-11",
        "isbn": "1234567890",
        "isbn13": "9791234567890",
        "coverURL": "https://example.com/detail.jpg",
        "categoryId": 1,
        "categoryName": "국내도서",
        "description": "짧은 설명",
        "fullDescription": "상세 설명",
        "priceStandard": 18000,
        "priceSales": 16200,
        "link": "https://example.com/book",
        "customerReviewRank": 8,
        "itemPage": 320,
        "tableOfContents": "목차",
        "story": "책 이야기",
        "relatedBooks": [
          {
            "title": "추천 도서",
            "authors": "추천 작가",
            "publisher": "추천 출판사",
            "publicationYear": "2025",
            "isbn13": "9788983921994",
            "coverURL": "https://example.com/related.jpg",
            "detailURL": "https://example.com/related"
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(BookDetailResponse.self, from: json)

    #expect(response.item.summary.id == "9791234567890")
    #expect(response.item.summary.description == "상세 설명")
    #expect(response.item.coverURL?.absoluteString == "https://example.com/detail.jpg")
    #expect(response.item.relatedBooks.first?.summary.id == "9788983921994")
    #expect(response.item.relatedBooks.first?.summary.author == "추천 작가")
  }

  @MainActor
  @Test func decodesBookDetailRelatedBookWithEmptyDetailURL() throws {
    let json = """
    {
      "item": {
        "title": "소년이 온다",
        "author": "한강",
        "publisher": "창비",
        "publishedDate": "2014-05-19",
        "isbn": "K662930932",
        "isbn13": "9788936434120",
        "coverURL": "https://example.com/detail.jpg",
        "categoryId": 50993,
        "categoryName": "국내도서",
        "description": "설명",
        "fullDescription": "",
        "priceStandard": 15000,
        "priceSales": 13500,
        "link": "https://example.com/book",
        "customerReviewRank": 10,
        "itemPage": 216,
        "tableOfContents": "",
        "story": "",
        "relatedBooks": [
          {
            "title": "작별하지 않는다",
            "authors": "한강",
            "publisher": "문학동네",
            "publicationYear": "2021",
            "isbn13": "9788954682152",
            "coverURL": "https://example.com/related.jpg",
            "detailURL": ""
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(BookDetailResponse.self, from: json)

    #expect(response.item.summary.id == "9788936434120")
    #expect(response.item.relatedBooks.first?.detailURL == nil)
  }

  private static func recommendationBook(
    title: String = "추천 후보",
    author: String = "작가",
    publisher: String = "출판사",
    description: String = "인문 철학 사유"
  ) -> BookSummary {
    BookSummary(
      isbn: "9791234567890",
      title: title,
      author: author,
      publisher: publisher,
      publishedDate: "2026",
      description: description,
      coverURL: nil
    )
  }

  private static func recommendationDetail(
    categoryName: String,
    relatedBooks: [RelatedBook] = []
  ) -> BookDetail {
    BookDetail(
      title: "추천 후보",
      author: "후보 작가",
      publisher: "출판사",
      publishedDate: "2026",
      isbn: "9791234567890",
      isbn13: "9791234567890",
      coverURL: nil,
      categoryId: 1,
      categoryName: categoryName,
      description: "새로운 책",
      fullDescription: "새로운 책",
      priceStandard: 0,
      priceSales: 0,
      link: nil,
      customerReviewRank: 0,
      itemPage: 0,
      tableOfContents: "",
      story: "",
      relatedBooks: relatedBooks
    )
  }
}

private struct FixedRecommendationRanker: RecommendationRanker {
  let score: Double?

  func score(input: RecommendationModelInput) -> Double? {
    score
  }
}

private final class CapturingRecommendationRanker: RecommendationRanker {
  let score: Double?
  private(set) var inputs: [RecommendationModelInput] = []

  init(score: Double?) {
    self.score = score
  }

  func score(input: RecommendationModelInput) -> Double? {
    inputs.append(input)
    return score
  }
}
