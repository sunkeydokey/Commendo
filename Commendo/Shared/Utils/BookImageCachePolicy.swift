//
//  BookImageCachePolicy.swift
//  Commendo
//
//  Created by Codex on 6/9/26.
//

import Foundation
import Kingfisher

enum BookImageCachePolicy {
  case newArrivalCover
  case hotNewArrivalCover
  case popularLoanCover

  var memoryExpiration: StorageExpiration {
    switch self {
    case .newArrivalCover, .hotNewArrivalCover, .popularLoanCover:
      .days(3)
    }
  }

  var diskExpiration: StorageExpiration {
    switch self {
    case .newArrivalCover, .hotNewArrivalCover, .popularLoanCover:
      .days(3)
    }
  }

  var accessExtending: ExpirationExtending {
    .none
  }
}
