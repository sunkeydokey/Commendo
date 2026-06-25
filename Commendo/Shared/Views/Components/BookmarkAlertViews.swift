//
//  BookmarkAlertViews.swift
//  Commendo
//
//  Created by Codex on 6/24/26.
//

import Foundation
import SwiftUI

struct BookmarkEditorAlertView: View {
  let title: String
  @Binding var rating: Double?
  @Binding var review: String
  let onCancel: () -> Void
  let onSave: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: DesignToken.Spacing.lg) {
      Text(title)
        .commendoTextStyle(DesignToken.Typography.cardTitle)

      VStack(alignment: .leading, spacing: DesignToken.Spacing.xs) {
        Text("평점")
          .commendoTextStyle(DesignToken.Typography.caption)

        RatingStarsView(rating: $rating)

        Text(ratingText)
          .commendoTextStyle(DesignToken.Typography.metadata, color: DesignToken.Color.textSecondary)
      }

      VStack(alignment: .leading, spacing: DesignToken.Spacing.xs) {
        Text("서평")
          .commendoTextStyle(DesignToken.Typography.caption)

        TextEditor(text: $review)
          .commendoTextStyle(DesignToken.Typography.body)
          .frame(minHeight: 112)
          .scrollContentBackground(.hidden)
          .padding(DesignToken.Spacing.xs)
          .background(DesignToken.Color.backgroundCream)
          .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.standard))
          .overlay {
            RoundedRectangle(cornerRadius: DesignToken.Radius.standard)
              .stroke(DesignToken.Color.borderLight, lineWidth: 1)
          }
      }

      HStack(spacing: DesignToken.Spacing.xs) {
        Button {
          onCancel()
        } label: {
          Text("취소")
            .commendoTextStyle(DesignToken.Typography.buttonSmall)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(DesignToken.Color.backgroundCream)
            .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.standard))
            .overlay {
              RoundedRectangle(cornerRadius: DesignToken.Radius.standard)
                .stroke(DesignToken.Color.charcoal40, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)

        Button {
          onSave()
        } label: {
          Text("저장")
            .commendoTextStyle(
              DesignToken.Typography.buttonSmall,
              color: canSave ? DesignToken.Color.textOnDark : DesignToken.Color.textSecondary
            )
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(canSave ? DesignToken.Color.charcoal : DesignToken.Color.charcoal04)
            .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.standard))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
      }
    }
    .padding(DesignToken.Spacing.xl)
    .background(DesignToken.Color.textOnDark)
    .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.card))
    .overlay {
      RoundedRectangle(cornerRadius: DesignToken.Radius.card)
        .stroke(DesignToken.Color.borderLight, lineWidth: 1)
    }
    .shadow(
      color: DesignToken.Shadow.focus.color,
      radius: DesignToken.Shadow.focus.radius,
      x: DesignToken.Shadow.focus.x,
      y: DesignToken.Shadow.focus.y
    )
  }

  private var canSave: Bool {
    guard let rating else {
      return false
    }

    return BookBookmark.isValidRating(rating)
  }

  private var ratingText: String {
    guard let rating else {
      return "별점을 선택해 주세요."
    }

    return String(format: "%.1f / 5.0", rating)
  }
}

struct BookmarkActionAlertView: View {
  let onEdit: () -> Void
  let onDelete: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: DesignToken.Spacing.lg) {
      Text("저장된 북마크")
        .commendoTextStyle(DesignToken.Typography.cardTitle)

      Text("평점과 서평을 수정하거나 북마크를 삭제할 수 있습니다.")
        .commendoTextStyle(DesignToken.Typography.caption, color: DesignToken.Color.textSecondary)

      VStack(spacing: DesignToken.Spacing.xs) {
        actionButton(title: "수정", systemImage: "pencil", action: onEdit)
        actionButton(title: "삭제", systemImage: "trash", roleColor: DesignToken.Color.textPrimary, action: onDelete)
        actionButton(title: "취소", systemImage: "xmark", action: onCancel)
      }
    }
    .padding(DesignToken.Spacing.xl)
    .background(DesignToken.Color.textOnDark)
    .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.card))
    .overlay {
      RoundedRectangle(cornerRadius: DesignToken.Radius.card)
        .stroke(DesignToken.Color.borderLight, lineWidth: 1)
    }
    .shadow(
      color: DesignToken.Shadow.focus.color,
      radius: DesignToken.Shadow.focus.radius,
      x: DesignToken.Shadow.focus.x,
      y: DesignToken.Shadow.focus.y
    )
  }

  private func actionButton(
    title: String,
    systemImage: String,
    roleColor: Color = DesignToken.Color.textPrimary,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label {
        Text(title)
          .commendoTextStyle(DesignToken.Typography.buttonSmall, color: roleColor)
      } icon: {
        Image(systemName: systemImage)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(roleColor)
      }
      .frame(maxWidth: .infinity, minHeight: 44)
      .background(DesignToken.Color.backgroundCream)
      .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.standard))
      .overlay {
        RoundedRectangle(cornerRadius: DesignToken.Radius.standard)
          .stroke(DesignToken.Color.borderLight, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }
}

private struct RatingStarsView: View {
  @Binding var rating: Double?

  var body: some View {
    HStack(spacing: DesignToken.Spacing.xs) {
      ForEach(1...5, id: \.self) { index in
        Image(systemName: imageName(for: index))
          .font(.system(size: 28, weight: .regular))
          .foregroundStyle(DesignToken.Color.textPrimary)
          .frame(width: 34, height: 34)
      }
    }
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          rating = ratingValue(at: value.location.x)
        }
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("평점")
    .accessibilityValue(rating.map { String(format: "%.1f점", $0) } ?? "선택 안 함")
  }

  private func imageName(for index: Int) -> String {
    guard let rating else {
      return "star"
    }

    let value = Double(index)
    if rating >= value {
      return "star.fill"
    } else if rating >= value - 0.5 {
      return "star.leadinghalf.filled"
    } else {
      return "star"
    }
  }

  private func ratingValue(at xPosition: CGFloat) -> Double {
    let stepWidth = (34 + DesignToken.Spacing.xs) / 2
    let rawValue = (xPosition / stepWidth).rounded(.up) * 0.5
    return min(max(rawValue, 0.5), 5.0)
  }
}
