//
//  TrendView.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import SunKit
import SunKitSwiftUI
import SwiftUI

struct TrendView: View {
  let apiClient: CommendoAPIClient

  @State private var selectedType: NewArrivalListType = .all

  @QueryBinding(
    queryOptions: QueryOptions(retry: .count(1)),
    cacheOptions: QueryCacheOptions(staleTime: 60 * 60 * 24 * 3, gcTime: 60 * 60 * 24 * 3)
  ) private var newArrivals: QueryState<NewArrivalBookPage, NewArrivalBookPage>

  private var chips: [SelectableChipItem] {
    NewArrivalListType.allCases.map { type in
      SelectableChipItem(id: type.rawValue, title: type.title)
    }
  }

  private let recentlyViewedBooks = [
    RecentBook(id: "recent-1", title: "고요한 밤의 독서"),
    RecentBook(id: "recent-2", title: "문장의 지도"),
    RecentBook(id: "recent-3", title: "오늘의 산책"),
  ]

  private let risingBooks = [
    RisingBook(id: "rising-1", rank: 1, title: "세계사의 쓸모", subtitle: "새로운 문명 읽기", isNew: true),
    RisingBook(id: "rising-2", rank: 2, title: "요즘의 사유", subtitle: "작고 단단한 생각들", isNew: false),
    RisingBook(id: "rising-3", rank: 3, title: "기억을 더듬어 걷기", subtitle: "산문의 시간", isNew: false),
  ]

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
          cachePolicy: selectedType == .special ? .hotNewArrivalCover : .newArrivalCover
        )

        RecentlyViewedSection(books: recentlyViewedBooks)
          .padding(.horizontal, 20)

        RisingLoanSection(books: risingBooks)
          .padding(.horizontal, 20)
          .padding(.bottom, 32)
      }
    }
    .scrollContentBackground(.hidden)
    .query(
      $newArrivals,
      key: ["books", "new-arrivals", AnyQueryKeyPart(selectedType.rawValue)]
    ) { [apiClient, selectedType] in
      try await apiClient.newArrivals(type: selectedType)
    }
  }
}

private struct RecentBook: Identifiable {
  let id: String
  let title: String
}

private struct RisingBook: Identifiable {
  let id: String
  let rank: Int
  let title: String
  let subtitle: String
  let isNew: Bool
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
  let books: [BookCardItem.Model]
  let cachePolicy: BookImageCachePolicy

  init(
    title: String,
    trailingTitle: String? = nil,
    books: [BookCardItem.Model],
    cachePolicy: BookImageCachePolicy
  ) {
    self.title = title
    self.trailingTitle = trailingTitle
    self.books = books
    self.cachePolicy = cachePolicy
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
            BookCardItem(model: book, coverTint: coverTint(at: index), cachePolicy: cachePolicy)
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

  private var books: [BookCardItem.Model] {
    page?.items.map { book in
      BookCardItem.Model(
        id: book.id,
        title: book.title,
        metadata: book.author,
        imageURL: book.coverURL
      )
    } ?? []
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
          cachePolicy: cachePolicy
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

private struct RecentlyViewedSection: View {
  let books: [RecentBook]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("최근 본 도서")
        .commendoTextStyle(DesignToken.Typography.cardTitle)

      HStack(spacing: 8) {
        ForEach(books) { book in
          RoundedRectangle(cornerRadius: DesignToken.Radius.standard)
            .fill(DesignToken.Color.charcoal04)
            .overlay {
              RoundedRectangle(cornerRadius: DesignToken.Radius.standard)
                .stroke(DesignToken.Color.borderLight, lineWidth: 1)
            }
            .frame(width: 48, height: 64)
            .accessibilityLabel(book.title)
        }
      }
    }
  }
}

private struct RisingLoanSection: View {
  let books: [RisingBook]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        Text("급상승 대출 도서")
          .commendoTextStyle(DesignToken.Typography.cardTitle)

        Spacer()

        Text("실시간")
          .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
      }

      VStack(spacing: 16) {
        ForEach(books) { book in
          RisingLoanRow(book: book)
        }
      }
    }
  }
}

private struct RisingLoanRow: View {
  let book: RisingBook

  var body: some View {
    HStack(spacing: 16) {
      Text("\(book.rank)")
        .commendoTextStyle(DesignToken.Typography.bodyLarge)
        .frame(width: 24, alignment: .leading)

      RoundedRectangle(cornerRadius: DesignToken.Radius.standard)
        .fill(DesignToken.Color.charcoal04)
        .overlay {
          RoundedRectangle(cornerRadius: DesignToken.Radius.standard)
            .stroke(DesignToken.Color.borderLight, lineWidth: 1)
        }
        .frame(width: 48, height: 64)

      VStack(alignment: .leading, spacing: 4) {
        Text(book.title)
          .commendoTextStyle(DesignToken.Typography.caption)
          .lineLimit(1)

        Text(book.subtitle)
          .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
          .lineLimit(1)
      }

      Spacer()

      if book.isNew {
        Text("NEW")
          .commendoTextStyle(DesignToken.Typography.badge, color: .red)
      } else {
        Image(systemName: "ellipsis")
      }
    }
    .frame(height: 80)
  }
}
