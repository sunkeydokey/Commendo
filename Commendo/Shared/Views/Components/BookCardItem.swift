//
//  BookCardItem.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import SwiftUI

struct BookCardItem: View {
  struct Model: Identifiable, Equatable {
    let id: String
    let title: String
    let metadata: String

    init(id: String, title: String, metadata: String) {
      self.id = id
      self.title = title
      self.metadata = metadata
    }
  }

  let model: Model
  let coverTint: Color

  init(model: Model, coverTint: Color = DesignToken.Color.charcoal04) {
    self.model = model
    self.coverTint = coverTint
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      RoundedRectangle(cornerRadius: DesignToken.Radius.comfortable)
        .fill(coverTint)
        .overlay {
          RoundedRectangle(cornerRadius: DesignToken.Radius.comfortable)
            .stroke(DesignToken.Color.borderLight, lineWidth: 1)
        }
        .frame(width: 180, height: 270)

      Text(model.title)
        .commendoTextStyle(DesignToken.Typography.caption)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)

      Text(model.metadata)
        .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
        .lineLimit(1)
        .padding(.top, 2)
    }
    .frame(width: 180, alignment: .leading)
  }
}

#Preview {
  BookCardItem(
    model: BookCardItem.Model(id: "1", title: "불편한 편의점", metadata: "김호연 지음")
  )
  .padding(.vertical, 20)
  .background(DesignToken.Color.backgroundCream)
}
