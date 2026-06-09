//
//  TypographyModifier.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import SwiftUI

private struct CommendoTextStyleModifier: ViewModifier {
  let style: TextStyle
  let color: Color

  func body(content: Content) -> some View {
    content
      .font(DesignToken.Typography.font(for: style))
      .tracking(style.letterSpacing)
      .lineSpacing(max(0, style.size * (style.lineHeight - 1)))
      .foregroundStyle(color)
  }
}

extension View {
  func commendoTextStyle(
    _ style: TextStyle,
    color: Color = DesignToken.Color.textPrimary
  ) -> some View {
    modifier(CommendoTextStyleModifier(style: style, color: color))
  }
}
