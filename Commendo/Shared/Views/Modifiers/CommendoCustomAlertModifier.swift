//
//  CommendoCustomAlertModifier.swift
//  Commendo
//
//  Created by Codex on 6/24/26.
//

import SwiftUI

private struct CommendoCustomAlertModifier<AlertContent: View>: ViewModifier {
  @Binding var isPresented: Bool
  let alertContent: () -> AlertContent

  func body(content: Content) -> some View {
    content
      .overlay {
        if isPresented {
          ZStack {
            Color.black.opacity(0.28)
              .ignoresSafeArea()

            alertContent()
              .frame(maxWidth: 360)
              .padding(.horizontal, DesignToken.Spacing.xl)
          }
          .transition(.opacity)
        }
      }
      .animation(.easeInOut(duration: 0.18), value: isPresented)
  }
}

extension View {
  func commendoCustomAlert<AlertContent: View>(
    isPresented: Binding<Bool>,
    @ViewBuilder content: @escaping () -> AlertContent
  ) -> some View {
    modifier(CommendoCustomAlertModifier(isPresented: isPresented, alertContent: content))
  }
}
