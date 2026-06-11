//
//  CommendoBackgroundView.swift
//  Commendo
//
//  Created by 이선기 on 6/11/26.
//

import SwiftUI

struct CommendoBackgroundView<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    ZStack {
      DesignToken.Color.backgroundCream
        .ignoresSafeArea()

      content()
    }
  }
}
