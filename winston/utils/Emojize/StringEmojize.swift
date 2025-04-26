//
//  StringEmojize.swift
//  winston
//
//  Created by Igor Marcossi on 31/07/23.
//

import Foundation

extension String {
  func emojied() -> String {
    var transformedString = self
    EMOJI_HASH.forEach { key, value in
      transformedString = transformedString.replacingOccurrences(of: key, with: value)
    }
    return transformedString
  }
  
  func cleanEmojis() -> String {
    do {
      let emojiRegex = try NSRegularExpression(pattern: ":(.*?):")
      return emojiRegex.stringByReplacingMatches(in: self, range: NSMakeRange(0, self.count), withTemplate: "")
    } catch {
      return self
    }
  }
}
