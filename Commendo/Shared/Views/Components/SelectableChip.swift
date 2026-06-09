//
//  SelectableChip.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import SwiftUI

struct SelectableChipItem: Identifiable, Equatable {
  let id: String
  let title: String

  init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

struct SelectableChip: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .commendoTextStyle(
          DesignToken.Typography.buttonSmall,
          color: isSelected ? DesignToken.Color.textOnDark : DesignToken.Color.textPrimary
        )
        .lineLimit(1)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(
          Capsule()
            .fill(isSelected ? DesignToken.Color.charcoal : DesignToken.Color.backgroundCream)
        )
        .overlay {
          Capsule()
            .stroke(
              isSelected ? DesignToken.Color.charcoal : DesignToken.Color.borderLight,
              lineWidth: 1
            )
        }
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  HStack(spacing: 10) {
    SelectableChip(title: "신간", isSelected: true) {}
    SelectableChip(title: "화제 신간", isSelected: false) {}
    SelectableChip(title: "베스트 셀러", isSelected: false) {}
  }
  .padding()
  .background(DesignToken.Color.backgroundCream)
}
