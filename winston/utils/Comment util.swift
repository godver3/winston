//
//  Comment util.swift
//  winston
//
//  Created by Ethan Bills on 1/11/24.
//

import Foundation
import SwiftUI

/// Utility class for handling comments.
class CommentUtils {
  /// Shared instance of CommentUtils.
  static let shared = CommentUtils()
  
  /// Private initializer to enforce singleton pattern.
  private init() {}
  
  // MARK: - Comment Section Helpers
  
  /// Preference key to track the anchor points of comments.
  struct AnchorsKey: PreferenceKey {
    typealias Value = [String: Anchor<CGPoint>]
    static var defaultValue: Value { [:] }
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
      value.merge(nextValue()) { $1 }
    }
  }
  
  /// Finds the top comment row based on anchors and geometry proxy.
  func topCommentRow(of anchors: CommentUtils.AnchorsKey.Value, in proxy: GeometryProxy) -> String? {
    var yBest = CGFloat.infinity
    var answer: String?
    for (row, anchor) in anchors {
      let y = proxy[anchor].y
      guard y >= 0, y < yBest else { continue }
      answer = row
      yBest = y
    }
    return answer
  }
    
  func flattenComments(_ comments: [Comment]) -> [[String: String]] {
    var savedMoreCalcs: [String: Int] = .init()
    return flattenCommentsIncludingMore(comments, savedMoreCalcs: &savedMoreCalcs)
      .filter({ $0["target"] != nil}) // Filter out kind = "more" messages
  }
  
  func flattenCommentsIncludingMore(_ comments: [Comment], savedMoreCalcs: inout [String: Int],  parentId: String? = nil) -> [[String: String]] {
    var flattened: [[String: String]] = []
    
    let maxPrevLines = 14
    var lastCommentId: String? = nil
    var lastCommentLines = 0
    var lastChildId: String? = nil
    var lastChildLines = 0
    
    comments.forEach { comment in
      if comment.kind != "more" {
        let useLastChild = lastChildLines <= maxPrevLines && lastChildId != nil
        let targetId = useLastChild ? lastChildId : (lastCommentId != nil ? (lastCommentLines > maxPrevLines ? nil : lastCommentId) : parentId)
        flattened.append([ "id": comment.id, "body": comment.data?.body?.lowercased() ?? "", "target": targetId ?? comment.id ])
      } else {
        flattened.append([ "id": comment.id, "body": "" ])
      }
      
      let approxLines = comment.data?.body?.approxLineCount() ?? 0
      var allChildrenLines = 2 * getMoreCount(comment, saved: &savedMoreCalcs)
      lastChildId = nil
      
      if comment.childrenWinston.count > 0 {
        let flattenedChildren = flattenCommentsIncludingMore(comment.childrenWinston, savedMoreCalcs: &savedMoreCalcs, parentId: approxLines <= maxPrevLines ? comment.id : nil)
        
        flattened.append(contentsOf: flattenedChildren)
        allChildrenLines = flattenedChildren.reduce(into: 0) { $0 += $1["body"]!.approxLineCount() }
        
        let lastChild = flattenedChildren.last!
        
        lastChildId = lastChild["id"]
        lastChildLines = lastChild["body"]!.approxLineCount()
      }
      
      lastCommentId = comment.id
      lastCommentLines = approxLines + allChildrenLines
    }
    
    return flattened
  }
  
  func getMoreCount(_ comment: Comment, saved: inout [String: Int]) -> Int {
    if let prev = saved[comment.id] { return prev }
    
    var moreCount = comment.kind == "more" ? 1 : 0
    moreCount += comment.childrenWinston.reduce(into: 0) { $0 += getMoreCount($1, saved: &saved)}
    saved[comment.id] = moreCount
    
    return moreCount
  }
}

extension String {
    func approxLineCount() -> Int {
      let newLines = self.numberOfOccurrences(of: "\n")
      // Assuming approx 40 chars per line
      return newLines + ((self.count - newLines * 2) / 40) + 2
    }
  
    func numberOfOccurrences(of: String) -> Int {
        return self.components(separatedBy: of).count - 1
    }
}
