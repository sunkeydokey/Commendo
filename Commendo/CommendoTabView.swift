//
//  CommendoTabView.swift
//  Commendo
//
//  Created by 이선기 on 6/8/26.
//

import SwiftUI

struct CommendoTabView: View {
  var body: some View {
    TabView {
      Tab("트렌드", systemImage: "flame") {
        CommendoTabContent {
          TrendView()
        }
      }
    }
  }
}

private struct CommendoTabContent<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    ZStack {
      DesignToken.Color.backgroundCream
        .ignoresSafeArea()

      content()
    }
  }
}
