//
//  TrendView.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import SwiftUI

struct TrendView: View {
  @State private var selectedChipID = "new"

  private let chips = [
    SelectableChipItem(id: "new", title: "신간"),
    SelectableChipItem(id: "hot-new", title: "화제 신간"),
    SelectableChipItem(id: "best-seller", title: "베스트 셀러"),
  ]

  private let newReleaseBooks = [
    BookCardItem.Model(id: "new-1", title: "흐릿한 끝에서 다시", metadata: "윤재연 지음"),
    BookCardItem.Model(id: "new-2", title: "편지와 사색", metadata: "박지민 지음"),
    BookCardItem.Model(id: "new-3", title: "여름의 문장들", metadata: "한서윤 지음"),
  ]

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
        SelectableChipBar(items: chips, selectedID: selectedChipID) { chip in
          selectedChipID = chip.id
        }
        .padding(.top, 16)

        HorizontalBookList(
          title: "신간 도서",
          trailingTitle: "더보기",
          books: newReleaseBooks
        )

        RecentlyViewedSection(books: recentlyViewedBooks)
          .padding(.horizontal, 20)

        RisingLoanSection(books: risingBooks)
          .padding(.horizontal, 20)
          .padding(.bottom, 32)
      }
    }
    .scrollContentBackground(.hidden)
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

  init(
    title: String,
    trailingTitle: String? = nil,
    books: [BookCardItem.Model]
  ) {
    self.title = title
    self.trailingTitle = trailingTitle
    self.books = books
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
            BookCardItem(model: book, coverTint: coverTint(at: index))
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
