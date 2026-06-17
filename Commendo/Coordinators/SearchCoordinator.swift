//
//  SearchCoordinator.swift
//  Commendo
//
//  Created by Codex on 6/17/26.
//

import Observation
import SwiftUI

enum SearchRoute: Hashable {
  case bookDetail(BookSummary)
  case availability(BookSummary)
}

@MainActor
@Observable
final class SearchCoordinator {
  var path = NavigationPath()

  func showBookDetail(_ book: BookSummary) {
    path.append(SearchRoute.bookDetail(book))
  }

  func showRelatedBook(_ book: BookSummary) {
    showBookDetail(book)
  }

  func showAvailability(_ book: BookSummary) {
    path.append(SearchRoute.availability(book))
  }

  func pop() {
    guard !path.isEmpty else { return }
    path.removeLast()
  }
}

struct SearchCoordinatorView: View {
  let apiClient: CommendoAPIClient
  @Bindable var coordinator: SearchCoordinator

  var body: some View {
    NavigationStack(path: $coordinator.path) {
      CommendoBackgroundView {
        SearchView(apiClient: apiClient, onSelectBook: coordinator.showBookDetail)
          .navigationDestination(for: SearchRoute.self) { route in
            destination(for: route)
          }
      }
    }
  }

  @ViewBuilder
  private func destination(for route: SearchRoute) -> some View {
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
