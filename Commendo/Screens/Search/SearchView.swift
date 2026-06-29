//
//  SearchView.swift
//  Commendo
//
//  Created by Codex on 6/17/26.
//

import SunKit
import SunKitSwiftUI
import SwiftUI

struct SearchView: View {
  let apiClient: CommendoAPIClient
  let onSelectBook: (BookSummary, RecommendationSourceContext) -> Void

  @State private var searchValue = ""
  @State private var committedSearchValue = ""
  @FocusState private var isSearchFocused: Bool

  @QueryBinding(
    queryOptions: QueryOptions(retry: .count(1)),
    cacheOptions: QueryCacheOptions(staleTime: 60 * 10, gcTime: 60 * 30)
  ) private var searchResults: QueryState<BookSearchPage, BookSearchPage>

  private let recentSearches = [
    "Happiness Design",
    "Mindful Architecture",
    "Silent Rooms",
    "Behavioral Spaces",
  ]

  private var committedSearchIsValid: Bool {
    !committedSearchValue.isEmpty
  }

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 32) {
        SearchHeader(
          searchValue: $searchValue,
          isSearchFocused: $isSearchFocused,
          recentSearches: recentSearches,
          onSubmit: commitSearch,
          onSelectRecentSearch: commitSearch
        )
        .padding(.top, 16)

        SearchResultsSection(
          page: searchResults.data,
          isPending: searchResults.isPending,
          isFetching: searchResults.isFetching,
          isStale: searchResults.result?.isStale == true,
          error: searchResults.error,
          committedSearchValue: committedSearchValue,
          onSelectBook: { book in onSelectBook(book, .searchResult) }
        )

        Button {
        } label: {
          PrimaryActionLabel(title: "Browse Curated Collections", systemImage: "books.vertical")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
      }
    }
    .scrollContentBackground(.hidden)
    .refreshable {
      guard committedSearchIsValid else { return }
      searchResults.refetch()
    }
    .query(
      $searchResults,
      key: ["books", "search", AnyQueryKeyPart(committedSearchValue)],
      enabled: committedSearchIsValid
    ) { [apiClient, committedSearchValue] in
      try await apiClient.searchBooks(query: committedSearchValue)
    }
  }

  private func commitSearch() {
    commitSearch(searchValue)
  }

  private func commitSearch(_ value: String) {
    guard let nextValue = SearchCommit.normalizedValue(from: value) else {
      return
    }

    if nextValue == committedSearchValue {
      searchResults.refetch()
    } else {
      committedSearchValue = nextValue
    }

    searchValue = nextValue
    isSearchFocused = false
  }
}

enum SearchCommit {
  static func normalizedValue(from value: String) -> String? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return (2...50).contains(normalized.count) ? normalized : nil
  }
}

private struct SearchHeader: View {
  @Binding var searchValue: String
  var isSearchFocused: FocusState<Bool>.Binding
  let recentSearches: [String]
  let onSubmit: () -> Void
  let onSelectRecentSearch: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      SearchField(
        searchValue: $searchValue,
        isSearchFocused: isSearchFocused,
        onSubmit: onSubmit
      )
      .padding(.horizontal, 20)

      VStack(alignment: .leading, spacing: 12) {
        Text("최근 검색어")
          .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)

        LazyVGrid(
          columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
          ],
          alignment: .leading,
          spacing: 10
        ) {
          ForEach(recentSearches, id: \.self) { search in
            SelectableChip(title: search, isSelected: false) {
              onSelectRecentSearch(search)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .padding(.horizontal, 20)
    }
  }
}

private struct SearchField: View {
  @Binding var searchValue: String
  var isSearchFocused: FocusState<Bool>.Binding
  let onSubmit: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 15, weight: .regular))
        .foregroundStyle(DesignToken.Color.textSecondary)

      TextField("Search books, authors, or curators", text: $searchValue)
        .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textPrimary)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .focused(isSearchFocused)
        .onSubmit(onSubmit)

      if !searchValue.isEmpty {
        Button {
          searchValue = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(DesignToken.Color.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("검색어 지우기")
      }
    }
    .frame(height: 48)
    .padding(.horizontal, 12)
    .background(DesignToken.Color.charcoal03)
    .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.comfortable))
    .overlay {
      RoundedRectangle(cornerRadius: DesignToken.Radius.comfortable)
        .stroke(DesignToken.Color.borderLight, lineWidth: 1)
    }
  }
}

private struct SearchResultsSection: View {
  let page: BookSearchPage?
  let isPending: Bool
  let isFetching: Bool
  let isStale: Bool
  let error: Error?
  let committedSearchValue: String
  let onSelectBook: (BookSummary) -> Void

  private var books: [BookSearchResult] {
    page?.items ?? []
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        Text("Search Results")
          .commendoTextStyle(DesignToken.Typography.cardTitle)

        Spacer()

        Text(statusTitle)
          .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
      }
      .padding(.horizontal, 20)

      if committedSearchValue.isEmpty {
        SearchMessageView(message: "검색어를 입력해 도서를 찾아보세요.")
          .padding(.horizontal, 20)
      } else if isPending && books.isEmpty {
        SearchLoadingList()
      } else if error != nil, books.isEmpty {
        SearchMessageView(message: "검색 결과를 불러오지 못했습니다.")
          .padding(.horizontal, 20)
      } else if books.isEmpty {
        SearchMessageView(message: "검색 결과가 없습니다.")
          .padding(.horizontal, 20)
      } else {
        VStack(spacing: 0) {
          ForEach(books) { book in
            SearchResultRow(book: book, onSelect: onSelectBook)
              .padding(.horizontal, 20)
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

    if let totalResults = page?.totalResults {
      return "\(totalResults) books found"
    }

    return "검색 대기"
  }
}

private struct SearchResultRow: View {
  let book: BookSearchResult
  let onSelect: (BookSummary) -> Void

  var body: some View {
    Button {
      onSelect(book.summary)
    } label: {
      HStack(spacing: 16) {
        BookCoverImage(
          imageURL: book.coverURL,
          width: 68,
          height: 92,
          cornerRadius: DesignToken.Radius.standard,
          placeholderColor: DesignToken.Color.charcoal04,
          cachePolicy: .newArrivalCover,
          showsBorder: true,
          showsShadow: false
        )

        VStack(alignment: .leading, spacing: 5) {
          Text(book.title)
            .commendoTextStyle(DesignToken.Typography.caption)
            .lineLimit(2)

          Text(book.author)
            .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
            .lineLimit(1)

          Text(book.publisher)
            .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
            .lineLimit(1)

          if !book.categoryName.isEmpty {
            Text(book.categoryName)
              .commendoTextStyle(DesignToken.Typography.badge, color: DesignToken.Color.textSecondary)
              .lineLimit(1)
              .padding(.top, 2)
          }
        }

        Spacer(minLength: 8)

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(DesignToken.Color.textSecondary)
      }
      .frame(minHeight: 132, alignment: .center)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private struct SearchLoadingList: View {
  var body: some View {
    VStack(spacing: 0) {
      ForEach(0..<4, id: \.self) { index in
        HStack(spacing: 16) {
          BookCoverImage(
            imageURL: nil,
            width: 68,
            height: 92,
            cornerRadius: DesignToken.Radius.standard,
            placeholderColor: DesignToken.Color.charcoal04
          )

          VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: DesignToken.Radius.micro)
              .fill(DesignToken.Color.charcoal04)
              .frame(width: 180, height: 14)

            RoundedRectangle(cornerRadius: DesignToken.Radius.micro)
              .fill(DesignToken.Color.charcoal04)
              .frame(width: 120, height: 10)
          }

          Spacer()
        }
        .frame(minHeight: 132)
        .padding(.horizontal, 20)
        .redacted(reason: .placeholder)
        .accessibilityLabel("검색 결과 로딩 \(index + 1)")
      }
    }
  }
}

private struct SearchMessageView: View {
  let message: String

  var body: some View {
    Text(message)
      .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
      .frame(maxWidth: .infinity, minHeight: 132, alignment: .center)
      .background(DesignToken.Color.charcoal03)
      .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.standard))
  }
}
