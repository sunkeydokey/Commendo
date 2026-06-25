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
  let onSelectRelatedBook: (BookSummary) -> Void
  let onFindAvailability: (() -> Void)?

  @Environment(\.modelContext) private var modelContext
  @Query private var bookmarks: [BookBookmark]
  @State private var isShowingBookmarkEditor = false
  @State private var isShowingBookmarkActions = false
  @State private var draftRating: Double?
  @State private var draftReview = ""

  @QueryBinding(
    queryOptions: QueryOptions(retry: .count(1)),
    cacheOptions: QueryCacheOptions(staleTime: 60 * 60 * 3, gcTime: 60 * 60 * 3)
  ) private var bookDetail: QueryState<BookDetailResponse, BookDetailResponse>

  init(
    apiClient: CommendoAPIClient,
    book: BookSummary,
    onSelectRelatedBook: @escaping (BookSummary) -> Void,
    onFindAvailability: (() -> Void)? = nil
  ) {
    self.apiClient = apiClient
    self.book = book
    self.onSelectRelatedBook = onSelectRelatedBook
    self.onFindAvailability = onFindAvailability
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
        insightSection
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
    .safeAreaInset(edge: .bottom, spacing: 0) {
      floatingActionArea
    }
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
        rating: draftRating,
        review: draftReview
      )
    } else {
      let bookmark = BookBookmark(
        book: displayedBook,
        bookID: book.id,
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
    VStack(alignment: .leading, spacing: DesignToken.Spacing.lg) {
      HStack {
        Text("잘 맞을 가능성이 높아요")
          .commendoTextStyle(DesignToken.Typography.caption)

        Spacer()

        Image(systemName: "sparkles")
          .foregroundStyle(DesignToken.Color.textPrimary)
      }

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(DesignToken.Color.borderLight)
          Capsule()
            .fill(DesignToken.Color.charcoal)
            .frame(width: proxy.size.width * content.compatibility)
        }
      }
      .frame(height: DesignToken.Spacing.xs)

      Text(content.compatibilityDescription)
        .commendoTextStyle(
          DesignToken.Typography.metadata,
          color: DesignToken.Color.textSecondary
        )
        .fixedSize(horizontal: false, vertical: true)
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

  private var insightSection: some View {
    VStack(alignment: .leading, spacing: DesignToken.Spacing.lg) {
      Text("Library Insight")
        .commendoTextStyle(DesignToken.Typography.detailSectionTitle)

      HStack(spacing: DesignToken.Spacing.lg) {
        insightCard(title: "주요 키워드") {
          HStack(spacing: DesignToken.Spacing.xs / 2) {
            ForEach(content.keywords, id: \.self) { keyword in
              Text(keyword)
                .commendoTextStyle(DesignToken.Typography.keyword)
                .padding(.horizontal, DesignToken.Spacing.xs)
                .padding(.vertical, DesignToken.Spacing.xs / 2)
                .background(DesignToken.Color.backgroundCream)
                .clipShape(Capsule())
                .overlay {
                  Capsule()
                    .stroke(DesignToken.Color.borderLight, lineWidth: 1)
                }
            }
          }
        }

        insightCard(title: "완독 예상 시간") {
          Text(content.estimatedReadingTime)
            .commendoTextStyle(DesignToken.Typography.body)
            .lineLimit(1)
        }
      }
    }
    .padding(.top, DesignToken.Spacing.xl)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(DesignToken.Color.borderLight)
        .frame(height: 1)
    }
    .padding(.horizontal, DesignToken.Spacing.xl - 4)
  }

  private func insightCard<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: DesignToken.Spacing.xs / 2) {
      Text(title)
        .commendoTextStyle(
          DesignToken.Typography.metadata,
          color: DesignToken.Color.textSecondary
        )

      content()

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
    .padding(DesignToken.Spacing.lg)
    .background(DesignToken.Color.textOnDark)
    .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.comfortable))
    .overlay {
      RoundedRectangle(cornerRadius: DesignToken.Radius.comfortable)
        .stroke(DesignToken.Color.borderLight, lineWidth: 1)
    }
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

  private var floatingActionArea: some View {
    VStack(spacing: 0) {
      Button {
        onFindAvailability?()
      } label: {
        PrimaryActionLabel(title: "소장 도서관 찾기", systemImage: "building.columns")
      }
      .buttonStyle(.plain)
      .allowsHitTesting(onFindAvailability != nil)
      .accessibilityHint("도서관 찾기 화면은 준비 중입니다")
    }
    .padding(.horizontal, DesignToken.Spacing.xl - 4)
    .padding(.top, DesignToken.Spacing.sectionSmall - 8)
    .padding(.bottom, DesignToken.Spacing.xl)
    .background {
      LinearGradient(
        colors: [
          DesignToken.Color.backgroundCream.opacity(0),
          DesignToken.Color.backgroundCream.opacity(0.9),
          DesignToken.Color.backgroundCream,
        ],
        startPoint: .top,
        endPoint: .bottom
      )
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
  let compatibility: CGFloat = 0.85
  let compatibilityDescription = "평소 선호하시는 철학적 사유와 간결한 문체가 이 책의 핵심 요소와 85% 일치합니다."
  let keywords = ["명상", "인문"]
  let estimatedReadingTime = "약 3시간 20분"
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
