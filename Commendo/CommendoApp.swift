//
//  CommendoApp.swift
//  Commendo
//
//  Created by 이선기 on 6/8/26.
//

import SwiftUI
import SunKit
import SunKitSwiftUI

@main
struct CommendoApp: App {
  private let apiClient: CommendoAPIClient?
  private let queryClient = QueryClient()
  @State private var tabCoordinator = TabCoordinator()

  init() {
    apiClient = try? CommendoAPIClient(configuration: AppConfiguration.load())
  }

  var body: some Scene {
    WindowGroup {
      if let apiClient {
        CommendoTabView(apiClient: apiClient, coordinator: tabCoordinator)
          .queryClient(queryClient)
      } else {
        Text("앱 설정을 확인해 주세요.")
          .commendoTextStyle(DesignToken.Typography.body, color: DesignToken.Color.textPrimary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(DesignToken.Color.backgroundCream)
      }
    }
  }
}
