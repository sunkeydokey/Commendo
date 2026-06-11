//
//  CommendoTabView.swift
//  Commendo
//
//  Created by 이선기 on 6/8/26.
//

import SwiftUI

struct CommendoTabView: View {
  let apiClient: CommendoAPIClient
  @Bindable var coordinator: TabCoordinator

  var body: some View {
    TabView(selection: $coordinator.selectedTab) {
      Tab("트렌드", systemImage: "flame", value: TabCoordinator.Tab.trend) {
        TrendCoordinatorView(
          apiClient: apiClient,
          coordinator: coordinator.trendCoordinator
        )
      }
    }
  }
}
