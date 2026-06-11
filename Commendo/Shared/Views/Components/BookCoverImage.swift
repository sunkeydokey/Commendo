//
//  BookCoverImage.swift
//  Commendo
//
//  Created by Codex on 6/10/26.
//

import Kingfisher
import SwiftUI

struct BookCoverImage: View {
  let imageURL: URL?
  let width: CGFloat
  let height: CGFloat
  let cornerRadius: CGFloat
  let placeholderColor: Color
  let cachePolicy: BookImageCachePolicy
  let showsBorder: Bool
  let showsShadow: Bool

  init(
    imageURL: URL?,
    width: CGFloat,
    height: CGFloat,
    cornerRadius: CGFloat = DesignToken.Radius.comfortable,
    placeholderColor: Color = DesignToken.Color.charcoal04,
    cachePolicy: BookImageCachePolicy = .newArrivalCover,
    showsBorder: Bool = true,
    showsShadow: Bool = false
  ) {
    self.imageURL = imageURL
    self.width = width
    self.height = height
    self.cornerRadius = cornerRadius
    self.placeholderColor = placeholderColor
    self.cachePolicy = cachePolicy
    self.showsBorder = showsBorder
    self.showsShadow = showsShadow
  }

  var body: some View {
    Group {
      if let imageURL {
        KFImage(imageURL)
          .memoryCacheExpiration(cachePolicy.memoryExpiration)
          .diskCacheExpiration(cachePolicy.diskExpiration)
          .memoryCacheAccessExtending(cachePolicy.accessExtending)
          .diskCacheAccessExtending(cachePolicy.accessExtending)
          .placeholder { placeholder }
          .resizable()
          .scaledToFill()
      } else {
        placeholder
      }
    }
    .frame(width: width, height: height)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    .overlay {
      if showsBorder {
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(DesignToken.Color.borderLight, lineWidth: 1)
      }
    }
    .shadow(
      color: showsShadow ? DesignToken.Shadow.bookCover.color : .clear,
      radius: showsShadow ? DesignToken.Shadow.bookCover.radius : 0,
      x: DesignToken.Shadow.bookCover.x,
      y: DesignToken.Shadow.bookCover.y
    )
  }

  private var placeholder: some View {
    Rectangle()
      .fill(placeholderColor)
  }
}
