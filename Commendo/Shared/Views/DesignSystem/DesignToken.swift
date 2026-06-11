//
//  DesignToken.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import SwiftUI

enum DesignToken {
  enum Color {
    static let backgroundCream = SwiftUI.Color("Cream", bundle: .main)
    static let textPrimary = SwiftUI.Color("Charcoal", bundle: .main)
    static let textSecondary = SwiftUI.Color("MutedGray", bundle: .main)
    static let textOnDark = SwiftUI.Color("OffWhite", bundle: .main)
    static let borderLight = SwiftUI.Color("LightCream", bundle: .main)
    static let focusRing = SwiftUI.Color("RingBlue", bundle: .main)

    static let charcoal = SwiftUI.Color("Charcoal", bundle: .main)
    static let charcoal83 = SwiftUI.Color("Charcoal83", bundle: .main)
    static let charcoal82 = SwiftUI.Color("Charcoal82", bundle: .main)
    static let charcoal40 = SwiftUI.Color("Charcoal40", bundle: .main)
    static let charcoal04 = SwiftUI.Color("Charcoal04", bundle: .main)
    static let charcoal03 = SwiftUI.Color("Charcoal03", bundle: .main)
  }

  enum Typography {
    static let appFontFamily = "Spoqa Han Sans Neo"
    static let brandImpactFontFamily = "Solmoe KimDaeGeon"
    static let fallbackFontFamily = "system"

    enum FontName {
      static let spoqaThin = "SpoqaHanSansNeo-Thin"
      static let spoqaLight = "SpoqaHanSansNeo-Light"
      static let spoqaRegular = "SpoqaHanSansNeo-Regular"
      static let spoqaMedium = "SpoqaHanSansNeo-Medium"
      static let spoqaBold = "SpoqaHanSansNeo-Bold"
      static let solMoeKdgLight = "SolmoeKimDaeGeonL"
      static let solMoeKdgMedium = "SolmoeKimDaeGeonM"
    }

    static let bodyWeight: CGFloat = 400
    static let displayAltWeight: CGFloat = 480
    static let headingWeight: CGFloat = 600

    static let displayHero = TextStyle(
      fontFamily: FontName.spoqaMedium,
      size: 60,
      weight: headingWeight,
      lineHeight: 1.10,
      letterSpacing: -1.5
    )
    static let displayAlt = TextStyle(
      fontFamily: FontName.solMoeKdgMedium,
      size: 60,
      weight: displayAltWeight,
      lineHeight: 1.00,
      letterSpacing: 0
    )
    static let sectionHeading = TextStyle(
      fontFamily: FontName.spoqaMedium,
      size: 48,
      weight: headingWeight,
      lineHeight: 1.00,
      letterSpacing: -1.2
    )
    static let subheading = TextStyle(
      fontFamily: FontName.spoqaMedium,
      size: 36,
      weight: headingWeight,
      lineHeight: 1.10,
      letterSpacing: -0.9
    )
    static let detailTitle = TextStyle(
      fontFamily: FontName.spoqaMedium,
      size: 28,
      weight: headingWeight,
      lineHeight: 1.25,
      letterSpacing: -0.5
    )
    static let detailSectionTitle = TextStyle(
      fontFamily: FontName.spoqaMedium,
      size: 24,
      weight: headingWeight,
      lineHeight: 1.17,
      letterSpacing: 0
    )
    static let cardTitle = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 20,
      weight: bodyWeight,
      lineHeight: 1.25,
      letterSpacing: 0
    )
    static let bodyLarge = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 18,
      weight: bodyWeight,
      lineHeight: 1.38,
      letterSpacing: 0
    )
    static let body = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 16,
      weight: bodyWeight,
      lineHeight: 1.50,
      letterSpacing: 0
    )
    static let detailBody = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 16,
      weight: bodyWeight,
      lineHeight: 1.625,
      letterSpacing: 0
    )
    static let button = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 16,
      weight: bodyWeight,
      lineHeight: 1.50,
      letterSpacing: 0
    )
    static let buttonSmall = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 14,
      weight: bodyWeight,
      lineHeight: 1.50,
      letterSpacing: 0
    )
    static let link = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 16,
      weight: bodyWeight,
      lineHeight: 1.50,
      letterSpacing: 0
    )
    static let linkSmall = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 14,
      weight: bodyWeight,
      lineHeight: 1.50,
      letterSpacing: 0
    )
    static let caption = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 14,
      weight: bodyWeight,
      lineHeight: 1.50,
      letterSpacing: 0
    )
    static let metadata = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 12,
      weight: bodyWeight,
      lineHeight: 1.35,
      letterSpacing: 0
    )
    static let badge = TextStyle(
      fontFamily: FontName.spoqaMedium,
      size: 10,
      weight: headingWeight,
      lineHeight: 1.20,
      letterSpacing: 0
    )
    static let keyword = TextStyle(
      fontFamily: FontName.spoqaRegular,
      size: 11,
      weight: bodyWeight,
      lineHeight: 1.45,
      letterSpacing: 0
    )

    static func font(for style: TextStyle) -> Font {
      Font.custom(fontName(for: style), size: style.size)
    }

    private static func fontName(for style: TextStyle) -> String {
      if let fontFamily = style.fontFamily {
        return fontFamily
      }

      if style.weight >= headingWeight {
        return FontName.spoqaMedium
      } else {
        return FontName.spoqaRegular
      }
    }
  }

  enum Spacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 10
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
    static let sectionSmall: CGFloat = 56
    static let section: CGFloat = 80
    static let sectionLarge: CGFloat = 96
    static let layout: CGFloat = 128
    static let layoutLarge: CGFloat = 176
    static let layoutXLarge: CGFloat = 192
    static let layoutXXLarge: CGFloat = 208
  }

  enum Radius {
    static let micro: CGFloat = 4
    static let standard: CGFloat = 6
    static let comfortable: CGFloat = 8
    static let card: CGFloat = 12
    static let container: CGFloat = 16
    static let pill: CGFloat = 9999
  }

  enum Shadow {
    static let focus = ShadowStyle(color: SwiftUI.Color.black.opacity(0.10), radius: 12, x: 0, y: 4)
    static let buttonDrop = ShadowStyle(color: SwiftUI.Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    static let bookCover = ShadowStyle(color: SwiftUI.Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
  }
}

struct TextStyle {
  let fontFamily: String?
  let size: CGFloat
  let weight: CGFloat
  let lineHeight: CGFloat
  let letterSpacing: CGFloat

  init(
    fontFamily: String? = nil,
    size: CGFloat,
    weight: CGFloat,
    lineHeight: CGFloat,
    letterSpacing: CGFloat
  ) {
    self.fontFamily = fontFamily
    self.size = size
    self.weight = weight
    self.lineHeight = lineHeight
    self.letterSpacing = letterSpacing
  }
}

struct ShadowStyle {
  let color: SwiftUI.Color
  let radius: CGFloat
  let x: CGFloat
  let y: CGFloat
}
