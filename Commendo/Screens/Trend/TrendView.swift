//
//  TrendView.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import SunKit
import SunKitSwiftUI
import SwiftData
import SwiftUI

struct TrendView: View {
  let apiClient: CommendoAPIClient
  let onSelectBook: (BookSummary, RecommendationSourceContext) -> Void

  @Environment(\.modelContext) private var modelContext
  @State private var selectedType: NewArrivalListType = .special
  @State private var myBooks: [BookBookmark] = []
  @State private var hasMoreMyBooks = false

  @QueryBinding(
    queryOptions: QueryOptions(retry: .count(1)),
    cacheOptions: QueryCacheOptions(staleTime: 60 * 60 * 3, gcTime: 60 * 60 * 3)
  ) private var newArrivals: QueryState<NewArrivalBookPage, NewArrivalBookPage>

  @QueryBinding(
    queryOptions: QueryOptions(retry: .count(1)),
    cacheOptions: QueryCacheOptions(staleTime: 60 * 60 * 3, gcTime: 60 * 60 * 3)
  ) private var popularLoans: QueryState<PopularLoanBookPage, PopularLoanBookPage>

  private var chips: [SelectableChipItem] {
    NewArrivalListType.allCases.map { type in
      SelectableChipItem(id: type.rawValue, title: type.title)
    }
  }

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 24) {
        SelectableChipBar(items: chips, selectedID: selectedType.rawValue) { chip in
          if let type = NewArrivalListType(rawValue: chip.id) {
            selectedType = type
          }
        }
        .padding(.top, 16)

        NewArrivalSection(
          title: selectedType.sectionTitle,
          page: newArrivals.data,
          isPending: newArrivals.isPending,
          isFetching: newArrivals.isFetching,
          isStale: newArrivals.result?.isStale == true,
          error: newArrivals.error,
          cachePolicy: selectedType == .special ? .hotNewArrivalCover : .newArrivalCover,
          onSelectBook: { book in onSelectBook(book, .newArrival) }
        )

        MyBooksSection(
          bookmarks: myBooks,
          hasMore: hasMoreMyBooks,
          onLoadMore: loadMoreMyBooks,
          onSelectBook: { book in onSelectBook(book, .none) }
        )
          .padding(.horizontal, 20)

        PopularLoanSection(
          page: popularLoans.data,
          isPending: popularLoans.isPending,
          isFetching: popularLoans.isFetching,
          isStale: popularLoans.result?.isStale == true,
          error: popularLoans.error,
          onSelectBook: { book in onSelectBook(book, .trend) }
        )
          .padding(.horizontal, 20)
          .padding(.bottom, 32)
      }
    }
    .scrollContentBackground(.hidden)
    .refreshable {
      newArrivals.refetch()
      popularLoans.refetch()
      loadInitialMyBooks()
    }
    .onAppear(perform: loadInitialMyBooks)
    .query(
      $newArrivals,
      key: ["books", "new-arrivals", AnyQueryKeyPart(selectedType.rawValue)]
    ) { [apiClient, selectedType] in
      try await apiClient.newArrivals(type: selectedType)
    }
    .query(
      $popularLoans,
      key: ["books", "trending"]
    ) { [apiClient] in
      try await apiClient.popularLoans()
    }
  }

  private func loadInitialMyBooks() {
    myBooks = []
    fetchMyBooks(offset: 0)
  }

  private func loadMoreMyBooks() {
    fetchMyBooks(offset: myBooks.count)
  }

  private func fetchMyBooks(offset: Int) {
    var descriptor = FetchDescriptor<BookBookmark>(
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )
    descriptor.fetchLimit = 11
    descriptor.fetchOffset = offset

    guard let fetchedBooks = try? modelContext.fetch(descriptor) else {
      hasMoreMyBooks = false
      return
    }

    hasMoreMyBooks = fetchedBooks.count > 10
    let page = Array(fetchedBooks.prefix(10))

    if offset == 0 {
      myBooks = page
    } else {
      myBooks.append(contentsOf: page)
    }
  }
}

private struct SelectableChipBar: View {
  let items: [SelectableChipItem]
  let selectedID: SelectableChipItem.ID?
  let onSelect: (SelectableChipItem) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(items) { item in
          SelectableChip(
            title: item.title,
            isSelected: item.id == selectedID
          ) {
            onSelect(item)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 4)
    }
  }
}

private struct HorizontalBookList: View {
  let title: String
  let trailingTitle: String?
  let books: [BookSummary]
  let cachePolicy: BookImageCachePolicy
  let onSelectBook: (BookSummary) -> Void

  init(
    title: String,
    trailingTitle: String? = nil,
    books: [BookSummary],
    cachePolicy: BookImageCachePolicy,
    onSelectBook: @escaping (BookSummary) -> Void
  ) {
    self.title = title
    self.trailingTitle = trailingTitle
    self.books = books
    self.cachePolicy = cachePolicy
    self.onSelectBook = onSelectBook
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .commendoTextStyle(DesignToken.Typography.cardTitle)

        Spacer()

        if let trailingTitle {
          Text(trailingTitle)
            .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
        }
      }
      .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
            Button {
              onSelectBook(book)
            } label: {
              BookCardItem(
                model: BookCardItem.Model(
                  id: book.id,
                  title: book.title,
                  metadata: book.author,
                  imageURL: book.coverURL
                ),
                coverTint: coverTint(at: index),
                cachePolicy: cachePolicy
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
      }
    }
  }

  private func coverTint(at index: Int) -> Color {
    switch index % 3 {
    case 0:
      DesignToken.Color.charcoal03
    case 1:
      DesignToken.Color.charcoal04
    default:
      DesignToken.Color.borderLight
    }
  }
}

private struct NewArrivalSection: View {
  let title: String
  let page: NewArrivalBookPage?
  let isPending: Bool
  let isFetching: Bool
  let isStale: Bool
  let error: Error?
  let cachePolicy: BookImageCachePolicy
  let onSelectBook: (BookSummary) -> Void

  private var books: [BookSummary] {
    page?.items.map(\.summary) ?? []
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if isPending && books.isEmpty {
        LoadingBookList(title: title)
      } else if error != nil, books.isEmpty {
        ErrorBookList(title: title)
      } else if books.isEmpty {
        EmptyBookList(title: title)
      } else {
        HorizontalBookList(
          title: title,
          trailingTitle: trailingTitle,
          books: books,
          cachePolicy: cachePolicy,
          onSelectBook: onSelectBook
        )
      }
    }
  }

  private var trailingTitle: String? {
    if isFetching {
      return "갱신 중"
    }

    if isStale, let fetchedAt = page?.fetchedAt {
      return "마지막 갱신 \(fetchedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    return "더보기"
  }
}

private struct LoadingBookList: View {
  let title: String

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(title)
        .commendoTextStyle(DesignToken.Typography.cardTitle)
        .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(0..<3, id: \.self) { index in
            BookCardItem(
              model: BookCardItem.Model(id: "loading-\(index)", title: " ", metadata: " "),
              coverTint: DesignToken.Color.charcoal04
            )
            .redacted(reason: .placeholder)
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }
}

private struct EmptyBookList: View {
  let title: String

  var body: some View {
    MessageBookList(title: title, message: "표시할 도서가 없습니다.")
  }
}

private struct ErrorBookList: View {
  let title: String

  var body: some View {
    MessageBookList(title: title, message: "도서를 불러오지 못했습니다.")
  }
}

private struct MessageBookList: View {
  let title: String
  let message: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .commendoTextStyle(DesignToken.Typography.cardTitle)

      Text(message)
        .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
        .background(DesignToken.Color.charcoal03)
        .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.standard))
    }
    .padding(.horizontal, 20)
  }
}

private struct MyBooksSection: View {
  let bookmarks: [BookBookmark]
  let hasMore: Bool
  let onLoadMore: () -> Void
  let onSelectBook: (BookSummary) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text("나의 도서")
          .commendoTextStyle(DesignToken.Typography.cardTitle)

        Spacer()

        Text("\(bookCountTitle)")
          .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
      }

      if bookmarks.isEmpty {
        Text("저장한 도서가 없습니다.")
          .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
          .frame(maxWidth: .infinity, minHeight: 88, alignment: .center)
          .background(DesignToken.Color.charcoal03)
          .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.standard))
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 16) {
            ForEach(Array(bookmarks.enumerated()), id: \.element.bookID) { index, bookmark in
              Button {
                onSelectBook(bookmark.summary)
              } label: {
                BookCardItem(
                  model: BookCardItem.Model(
                    id: bookmark.bookID,
                    title: bookmark.title,
                    metadata: bookmark.author,
                    imageURL: bookmark.summary.coverURL
                  ),
                  coverTint: coverTint(at: index),
                  cachePolicy: .newArrivalCover
                )
              }
              .buttonStyle(.plain)
            }

            if hasMore {
              Button {
                onLoadMore()
              } label: {
                VStack(spacing: 8) {
                  Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignToken.Color.textPrimary)

                  Text("더보기")
                    .commendoTextStyle(DesignToken.Typography.metadata)
                }
                .frame(width: 88, height: 270)
                .background(DesignToken.Color.charcoal03)
                .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.comfortable))
                .overlay {
                  RoundedRectangle(cornerRadius: DesignToken.Radius.comfortable)
                    .stroke(DesignToken.Color.borderLight, lineWidth: 1)
                }
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.bottom, 4)
        }
      }
    }
  }

  private var bookCountTitle: String {
    hasMore ? "\(bookmarks.count)+" : "\(bookmarks.count)권"
  }

  private func coverTint(at index: Int) -> Color {
    switch index % 3 {
    case 0:
      DesignToken.Color.charcoal03
    case 1:
      DesignToken.Color.charcoal04
    default:
      DesignToken.Color.borderLight
    }
  }
}

private struct PopularLoanSection: View {
  let page: PopularLoanBookPage?
  let isPending: Bool
  let isFetching: Bool
  let isStale: Bool
  let error: Error?
  let onSelectBook: (BookSummary) -> Void

  private var books: [PopularLoanBook] {
    page?.items ?? []
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        Text("베스트셀러")
          .commendoTextStyle(DesignToken.Typography.cardTitle)

        Spacer()

        Text(statusTitle)
          .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
      }

      if isPending && books.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity, minHeight: 120)
      } else if error != nil, books.isEmpty {
        Text("베스트셀러를 불러오지 못했습니다.")
          .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
          .frame(maxWidth: .infinity, minHeight: 120)
      } else if books.isEmpty {
        Text("표시할 베스트셀러가 없습니다.")
          .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
          .frame(maxWidth: .infinity, minHeight: 120)
      } else {
        VStack(spacing: 16) {
          ForEach(books) { book in
            PopularLoanRow(book: book, onSelect: onSelectBook)
          }
        }
      }
    }
  }

  private var statusTitle: String {
    if isFetching {
      return "갱신 중"
    }

    if isStale, let fetchedAt = page?.fetchedAt {
      return "마지막 갱신 \(fetchedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    return "오늘 기준"
  }
}

private struct PopularLoanRow: View {
  let book: PopularLoanBook
  let onSelect: (BookSummary) -> Void

  var body: some View {
    Button {
      onSelect(book.summary)
    } label: {
      HStack(spacing: 16) {
        Text("\(book.rank)")
          .commendoTextStyle(DesignToken.Typography.bodyLarge)
          .frame(width: 24, alignment: .leading)

        BookCoverImage(
          imageURL: book.coverURL,
          width: 48,
          height: 64,
          cornerRadius: DesignToken.Radius.standard,
          cachePolicy: .popularLoanCover,
          showsBorder: false
        )

        VStack(alignment: .leading, spacing: 4) {
          Text(book.title)
            .commendoTextStyle(DesignToken.Typography.caption)
            .lineLimit(1)

          Text(book.authors)
            .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
            .lineLimit(1)
        }

        Spacer()

        if !book.publicationYear.isEmpty {
          Text(book.publicationYear)
            .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(height: 80)
  }
}
