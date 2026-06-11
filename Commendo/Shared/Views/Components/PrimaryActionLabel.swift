//
//  PrimaryActionLabel.swift
//  Commendo
//
//  Created by Codex on 6/10/26.
//

import SwiftUI

struct PrimaryActionLabel: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label {
      Text(title)
        .commendoTextStyle(DesignToken.Typography.buttonSmall, color: DesignToken.Color.textOnDark)
    } icon: {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(DesignToken.Color.textOnDark)
    }
    .frame(maxWidth: .infinity, minHeight: 56)
    .background(DesignToken.Color.charcoal)
    .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.comfortable))
    .shadow(
      color: DesignToken.Shadow.buttonDrop.color,
      radius: DesignToken.Shadow.buttonDrop.radius,
      x: DesignToken.Shadow.buttonDrop.x,
      y: DesignToken.Shadow.buttonDrop.y
    )
  }
}
