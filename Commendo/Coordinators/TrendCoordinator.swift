//
//  TrendCoordinator.swift
//  Commendo
//
//  Created by Codex on 6/10/26.
//

import Observation
import SwiftUI

enum TrendRoute: Hashable {
  case bookDetail(BookSummary)
  case availability(BookSummary)
}

@MainActor
@Observable
final class TrendCoordinator {
  var path = NavigationPath()

  func showBookDetail(_ book: BookSummary) {
    path.append(TrendRoute.bookDetail(book))
  }

  func showRelatedBook(_ book: BookSummary) {
    showBookDetail(book)
  }

  func showAvailability(_ book: BookSummary) {
    path.append(TrendRoute.availability(book))
  }

  func pop() {
    guard !path.isEmpty else { return }
    path.removeLast()
  }
}

struct TrendCoordinatorView: View {
  let apiClient: CommendoAPIClient
  @Bindable var coordinator: TrendCoordinator

  var body: some View {
    NavigationStack(path: $coordinator.path) {
      CommendoBackgroundView {
        TrendView(apiClient: apiClient, onSelectBook: coordinator.showBookDetail)
          .navigationDestination(for: TrendRoute.self) { route in
            destination(for: route)
          }
      }
    }
  }

  @ViewBuilder
  private func destination(for route: TrendRoute) -> some View {
    switch route {
    case .bookDetail(let book):
      BookDetailView(
        apiClient: apiClient,
        book: book,
        onSelectRelatedBook: coordinator.showRelatedBook
      )
    case .availability:
      EmptyView()
    }
  }
}
