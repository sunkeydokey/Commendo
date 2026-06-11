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
  }

  var selectedTab: Tab = .trend
  let trendCoordinator = TrendCoordinator()
}
