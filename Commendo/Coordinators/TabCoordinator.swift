//
//  TabCoordinator.swift
//  Commendo
//
//  Created by Codex on 6/10/26.
//

import Observation

@MainActor
@Observable
final class TabCoordinator {
  enum Tab: Hashable {
    case trend
    case search
  }

  var selectedTab: Tab = .trend
  let trendCoordinator = TrendCoordinator()
  let searchCoordinator = SearchCoordinator()
}
