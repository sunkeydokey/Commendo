//
//  BookDetailView.swift
//  Commendo
//
//  Created by Codex on 6/10/26.
//

import SunKit
import SunKitSwiftUI
import SwiftData
import SwiftUI

struct BookDetailView: View {
  let apiClient: CommendoAPIClient
  let book: BookSummary
  let sourceContext: RecommendationSourceContext
  let onSelectRelatedBook: (BookSummary) -> Void

  @Environment(\.modelContext) private var modelContext
  @Query private var bookmarks: [BookBookmark]
  @Query(sort: \BookBookmark.updatedAt, order: .reverse) private var allBookmarks: [BookBookmark]
  @State private var isShowingBookmarkEditor = false
  @State private var isShowingBookmarkActions = false
  @State private var draftRating: Double?
  @State private var draftReview = ""
  private let recommendationScoringService = RecommendationScoringService()

  @QueryBinding(
    queryOptions: QueryOptions(retry: .count(1)),
    cacheOptions: QueryCacheOptions(staleTime: 60 * 60 * 3, gcTime: 60 * 60 * 3)
  ) private var bookDetail: QueryState<BookDetailResponse, BookDetailResponse>

  init(
    apiClient: CommendoAPIClient,
    book: BookSummary,
    sourceContext: RecommendationSourceContext = .none,
    onSelectRelatedBook: @escaping (BookSummary) -> Void
  ) {
    self.apiClient = apiClient
    self.book = book
    self.sourceContext = sourceContext
    self.onSelectRelatedBook = onSelectRelatedBook
    let bookID = book.id
    _bookmarks = Query(
      filter: #Predicate<BookBookmark> { bookmark in
        bookmark.bookID == bookID
      },
      sort: \BookBookmark.updatedAt,
      order: .reverse
    )
  }

  private var displayedBook: BookSummary {
    bookDetail.data?.item.summary ?? book
  }

  private var content: BookDetailContent {
    BookDetailContent(book: displayedBook)
  }

  private var relatedBooks: [BookSummary] {
    bookDetail.data?.item.relatedBooks.map(\.summary) ?? []
  }

  private var currentBookmark: BookBookmark? {
    bookmarks.first
  }

  private var recommendationResult: RecommendationResult {
    recommendationScoringService.score(
      book: displayedBook,
      detail: bookDetail.data?.item,
      bookmarks: allBookmarks,
      sourceContext: sourceContext
    )
  }

  private var isBookmarked: Bool {
    currentBookmark != nil
  }

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(spacing: 0) {
        serverStatusView
        heroSection
        compatibilitySection
        introductionSection
        relatedBooksSection
      }
      .padding(.bottom, DesignToken.Spacing.xl)
    }
    .background(DesignToken.Color.backgroundCream)
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          handleBookmarkButtonTap()
        } label: {
          Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            .foregroundStyle(DesignToken.Color.textPrimary)
        }
        .accessibilityLabel(isBookmarked ? "북마크 해제" : "북마크 추가")
      }
    }
    .toolbar(.hidden, for: .tabBar)
    .commendoCustomAlert(isPresented: $isShowingBookmarkActions) {
      BookmarkActionAlertView(
        onEdit: openBookmarkEditorForExistingBookmark,
        onDelete: deleteBookmark,
        onCancel: { isShowingBookmarkActions = false }
      )
    }
    .commendoCustomAlert(isPresented: $isShowingBookmarkEditor) {
      BookmarkEditorAlertView(
        title: isBookmarked ? "북마크 수정" : "북마크 저장",
        rating: $draftRating,
        review: $draftReview,
        onCancel: { isShowingBookmarkEditor = false },
        onSave: saveBookmark
      )
    }
    .query(
      $bookDetail,
      key: ["books", "detail", "v6", AnyQueryKeyPart(book.isbn)],
      enabled: BookIdentifier.isbn13(book.isbn) != nil
    ) { [apiClient, isbn = book.isbn] in
      try await apiClient.bookDetail(isbn: isbn)
    }
  }

  private func handleBookmarkButtonTap() {
    if isBookmarked {
      isShowingBookmarkActions = true
    } else {
      draftRating = nil
      draftReview = ""
      isShowingBookmarkEditor = true
    }
  }

  private func openBookmarkEditorForExistingBookmark() {
    guard let bookmark = currentBookmark else {
      isShowingBookmarkActions = false
      return
    }

    draftRating = bookmark.rating
    draftReview = bookmark.review ?? ""
    isShowingBookmarkActions = false
    isShowingBookmarkEditor = true
  }

  private func saveBookmark() {
    guard let draftRating,
          BookBookmark.isValidRating(draftRating) else {
      return
    }

    if let currentBookmark {
      currentBookmark.update(
        from: displayedBook,
        categoryName: bookDetail.data?.item.categoryName,
        rating: draftRating,
        review: draftReview
      )
    } else {
      let bookmark = BookBookmark(
        book: displayedBook,
        bookID: book.id,
        categoryName: bookDetail.data?.item.categoryName,
        rating: draftRating,
        review: draftReview
      )
      modelContext.insert(bookmark)
    }

    try? modelContext.save()
    isShowingBookmarkEditor = false
  }

  private func deleteBookmark() {
    guard let currentBookmark else {
      isShowingBookmarkActions = false
      return
    }

    modelContext.delete(currentBookmark)
    try? modelContext.save()
    isShowingBookmarkActions = false
  }

  @ViewBuilder
  private var serverStatusView: some View {
    if bookDetail.isFetching || bookDetail.result?.isStale == true || bookDetail.error != nil {
      HStack(spacing: DesignToken.Spacing.xs) {
        if bookDetail.isFetching {
          ProgressView()
            .controlSize(.small)
        }

        Text(serverStatusTitle)
          .commendoTextStyle(
            DesignToken.Typography.metadata,
            color: DesignToken.Color.textSecondary
          )

        Spacer()

        if bookDetail.error != nil {
          Button("다시 시도") {
            bookDetail.refetch()
          }
          .buttonStyle(.bordered)
        }
      }
      .padding(.horizontal, DesignToken.Spacing.xl - 4)
      .padding(.top, DesignToken.Spacing.lg)
    }
  }

  private var serverStatusTitle: String {
    if bookDetail.isFetching {
      return "상세 정보를 갱신 중입니다."
    }

    if bookDetail.error != nil {
      return "갱신에 실패해 저장된 정보를 표시합니다."
    }

    if bookDetail.result?.isStale == true, let updatedAt = bookDetail.result?.updatedAt {
      return "마지막 갱신 \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    return ""
  }

  private var heroSection: some View {
    VStack(spacing: 0) {
      BookCoverImage(
        imageURL: displayedBook.coverURL,
        width: 233.33,
        height: 350,
        cachePolicy: .newArrivalCover,
        showsShadow: true
      )
      .padding(.bottom, DesignToken.Spacing.xl)

      VStack(spacing: DesignToken.Spacing.xs / 2) {
        Text(displayedBook.title)
          .commendoTextStyle(DesignToken.Typography.detailTitle)
          .multilineTextAlignment(.center)

        Text(displayedBook.author)
          .commendoTextStyle(
            DesignToken.Typography.bodyLarge,
            color: DesignToken.Color.textSecondary
          )
          .multilineTextAlignment(.center)

        HStack(spacing: DesignToken.Spacing.xs) {
          Text(displayedBook.publisher)
          Circle()
            .fill(DesignToken.Color.borderLight)
            .frame(width: 4, height: 4)
          Text(displayedBook.publishedDate)
        }
        .commendoTextStyle(
          DesignToken.Typography.metadata,
          color: DesignToken.Color.textSecondary
        )
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, DesignToken.Spacing.xl)
    .padding(.vertical, DesignToken.Spacing.xl)
  }

  private var compatibilitySection: some View {
    let recommendation = recommendationResult

    return VStack(alignment: .leading, spacing: DesignToken.Spacing.lg) {
      HStack {
        Text("추천지수 \(recommendation.score)")
          .commendoTextStyle(DesignToken.Typography.caption)

        Spacer()

        Text(confidenceTitle(for: recommendation.confidence))
          .commendoTextStyle(
            DesignToken.Typography.metadata,
            color: DesignToken.Color.textSecondary
          )
      }

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(DesignToken.Color.borderLight)
          Capsule()
            .fill(DesignToken.Color.charcoal)
            .frame(width: proxy.size.width * CGFloat(recommendation.score) / 100)
        }
      }
      .frame(height: DesignToken.Spacing.xs)

      VStack(alignment: .leading, spacing: DesignToken.Spacing.xs / 2) {
        ForEach(recommendation.reasons, id: \.self) { reason in
          Text(reason)
            .commendoTextStyle(
              DesignToken.Typography.metadata,
              color: DesignToken.Color.textSecondary
            )
            .fixedSize(horizontal: false, vertical: true)
        }

        Text(recommendation.disclaimer)
          .commendoTextStyle(
            DesignToken.Typography.metadata,
            color: DesignToken.Color.textSecondary
          )
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(DesignToken.Spacing.xl)
    .background(DesignToken.Color.charcoal03)
    .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.card))
    .overlay {
      RoundedRectangle(cornerRadius: DesignToken.Radius.card)
        .stroke(DesignToken.Color.borderLight, lineWidth: 1)
    }
    .padding(.horizontal, DesignToken.Spacing.xl - 4)
  }

  private func confidenceTitle(for confidence: RecommendationConfidence) -> String {
    switch confidence {
    case .low:
      return "신뢰도 낮음"
    case .medium:
      return "신뢰도 보통"
    case .high:
      return "신뢰도 높음"
    }
  }

  private var introductionSection: some View {
    VStack(alignment: .leading, spacing: DesignToken.Spacing.lg) {
      Text("도서 소개")
        .commendoTextStyle(DesignToken.Typography.detailSectionTitle)

      VStack(alignment: .leading, spacing: DesignToken.Spacing.lg) {
        ForEach(Array(content.descriptionParagraphs.enumerated()), id: \.offset) { _, paragraph in
          Text(paragraph)
            .commendoTextStyle(
              DesignToken.Typography.detailBody,
              color: DesignToken.Color.textSecondary
            )
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.horizontal, DesignToken.Spacing.xl - 4)
    .padding(.vertical, DesignToken.Spacing.sectionSmall - 8)
  }

  @ViewBuilder
  private var relatedBooksSection: some View {
    if !relatedBooks.isEmpty {
      VStack(alignment: .leading, spacing: DesignToken.Spacing.lg) {
        Text("함께 읽으면 좋은 책")
          .commendoTextStyle(DesignToken.Typography.detailSectionTitle)
          .padding(.horizontal, DesignToken.Spacing.xl - 4)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: DesignToken.Spacing.lg) {
            ForEach(relatedBooks) { relatedBook in
              Button {
                onSelectRelatedBook(relatedBook)
              } label: {
                RelatedBookItem(book: relatedBook)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, DesignToken.Spacing.xl - 4)
          .padding(.bottom, DesignToken.Spacing.xs / 2)
        }
      }
      .padding(.top, DesignToken.Spacing.sectionSmall - 8)
    }
  }

}

private struct RelatedBookItem: View {
  let book: BookSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      BookCoverImage(
        imageURL: book.coverURL,
        width: 140,
        height: 210,
        cachePolicy: .newArrivalCover
      )

      Text(book.title)
        .commendoTextStyle(DesignToken.Typography.caption)
        .lineLimit(1)
        .padding(.top, DesignToken.Spacing.xs)

      Text(book.author)
        .commendoTextStyle(
          DesignToken.Typography.metadata,
          color: DesignToken.Color.textSecondary
        )
        .lineLimit(1)
    }
    .frame(width: 140, alignment: .leading)
  }
}

private struct BookDetailContent {
  let descriptionParagraphs: [String]

  init(book: BookSummary) {
    if book.description.isEmpty {
      descriptionParagraphs = [
        "현대 사회의 소음 속에서 잃어버린 침묵의 본질적인 가치를 탐구하는 책입니다. 저자는 침묵이 단순히 소리가 없는 상태가 아니라 인간의 내면을 돌아보는 바탕임을 이야기합니다.",
        "언어가 힘을 잃고 소음이 되어버린 시대에 다시금 침묵을 통해 세계와 마주하는 법을 제안합니다.",
      ]
    } else {
      descriptionParagraphs = [book.description]
    }
  }
}

#Preview {
  NavigationStack {
    BookDetailView(
      apiClient: CommendoAPIClient(baseURL: URL(string: "https://example.com")!),
      book: BookSummary(
        isbn: "9788972916941",
        title: "침묵의 세계",
        author: "막스 피카르트",
        publisher: "까치",
        publishedDate: "2023.10.15",
        description: "현대 사회의 소음 속에서 잃어버린 침묵의 본질적인 가치를 탐구하는 고전입니다. 저자는 침묵이 단순히 소리가 없는 상태가 아니라, 인간 영혼이 숨 쉬는 근원적인 바탕임을 강조합니다.",
        coverURL: nil
      ),
      onSelectRelatedBook: { _ in }
    )
  }
  .modelContainer(for: BookBookmark.self, inMemory: true)
}
