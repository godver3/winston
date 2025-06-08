//
//  Comment.swift
//  winston
//
//  Created by Igor Marcossi on 28/06/23.
//

import SwiftUI
import Defaults
import SwiftUIIntrospect

let ZINDEX_SLOTS_COMMENT = 100000

struct Top: Shape {
  func path(in rect: CGRect) -> Path {
    let path = UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 20, height: 20))
    return Path(path.cgPath)
  }
}

enum CommentBGSide {
  case top
  case middle
  case bottom
  case single
  
  static func getFromArray(count: Int, i: Int) -> Self {
    if !IPAD { return .middle }
    let finalIndex = count - 1
    if count == 1 { return .single }
    if i == 0 { return .top }
    if i == finalIndex { return .bottom }
    return .middle
  }
}

struct CommentBG: Shape {
  var cornerRadius: CGFloat = 10
  var pos: CommentBGSide
  func path(in rect: CGRect) -> Path {
    var roundingCorners: UIRectCorner = []
    
    switch pos {
    case .top:
      roundingCorners = [.topLeft, .topRight]
    case .middle:
      roundingCorners = []
    case .bottom:
      roundingCorners = [.bottomLeft, .bottomRight]
    case .single:
      roundingCorners = [.bottomLeft, .bottomRight, .topLeft, .topRight]
    }
    let path = UIBezierPath(roundedRect: rect, byRoundingCorners: roundingCorners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
    return Path(path.cgPath)
  }
}


class SubCommentsReferencesContainer: ObservableObject {
  @Published var data: [Comment] = []
}

struct CommentLinkDecoration: View, Equatable {
  static func == (lhs: CommentLinkDecoration, rhs: CommentLinkDecoration) -> Bool {
    lhs.top == rhs.top &&
    lhs.comment == rhs.comment &&
    lhs.currentMatchId == rhs.currentMatchId &&
    lhs.highlightCurrentMatch == rhs.highlightCurrentMatch
  }
  
  let top: Bool
  let comment: Comment
  let currentMatchId: String?
  let highlightCurrentMatch: Bool
  let theme: CommentsSectionTheme
  
  var body: some View {
    let highlight = highlightCurrentMatch && (((top || comment.childrenWinston.count == 0) && currentMatchId == comment.id) || (!top && CommentUtils.shared.getLastChild(comment) == currentMatchId))
    Spacer()
      .frame(maxWidth: .infinity, minHeight: theme.theme.cornerRadius * 2, maxHeight: theme.theme.cornerRadius * 2, alignment: .top)
      .background(highlight ? Color.gray.opacity(0.17) : theme.theme.bg())
//      .frame(maxWidth: .infinity, minHeight: theme.theme.cornerRadius, maxHeight: theme.theme.cornerRadius, alignment: .top)
//      .clipped()
  }
}

struct CommentLink: View, Equatable {
  static func == (lhs: CommentLink, rhs: CommentLink) -> Bool {
    lhs.post == rhs.post &&
    lhs.subreddit == rhs.subreddit &&
    lhs.indentLines == rhs.indentLines &&
    lhs.highlightID == rhs.highlightID &&
    lhs.searchQuery == rhs.searchQuery &&
    lhs.isMatch == rhs.isMatch &&
    lhs.matchMap == rhs.matchMap &&
    lhs.commentIndexMap == rhs.commentIndexMap &&
    lhs.topCommentIdx == rhs.topCommentIdx &&
    lhs.currentMatchId == rhs.currentMatchId &&
    lhs.highlightCurrentMatch == rhs.highlightCurrentMatch &&
    lhs.fadeSeenComments == rhs.fadeSeenComments &&
    lhs.comment == rhs.comment &&
    lhs.parentElement == rhs.parentElement &&
    lhs.children == rhs.children
  }
  
  var lineLimit: Int?
  var highlightID: String?
  var post: Post?
  var subreddit: Subreddit?
  var arrowKinds: [ArrowKind] = []
  var indentLines: Int? = nil
  var avatarsURL: [String:String]? = nil
  var postFullname: String?
  var showReplies = true
  var seenComments: String?
  var fadeSeenComments: Bool = false
  var parentElement: CommentParentElement? = nil
  
  var comment: Comment
  var commentWinstonData: CommentWinstonData
  var children: [Comment]
  
  var searchQuery: String? = nil
  var matchMap: [String: String] = [:]
  var isMatch: Bool = false
  
  var currentMatchId: String? = nil
  
  var topCommentIdx: Int = 0
  var commentIndexMap: [String: Int] = [:]
  
  var highlightCurrentMatch: Bool = false
  var updateVisibleComments: ((String, Bool) -> Void)?
  var newCommentsLoaded: (() -> Void)?
  
  var parentShowReplies = true
  var parentArrowKinds: [ArrowKind] = []
  var parentIndentLines: Int? = nil
  var parentLineLimit: Int? = nil
  var parentComment: Comment? = nil
  var parentAvatarsURL: [String:String]?
  
  var index: Int = 0
  var commentLinkMore: CommentLinkMore? = nil
  
  var body: some View {
    if let data = comment.data {
      let collapsed = (data.collapsed ?? false) && (!highlightCurrentMatch || !comment.containsCurrentMatch(currentMatchId))
      Group {
        Group {
          if let kind = comment.kind, kind == "more" {
            if comment.id == "_" {
              if let post = post {
                CommentLinkFull(post: post, arrowKinds: arrowKinds, comment: comment, indentLines: indentLines)
              }
            } else {
              CommentLinkMore(arrowKinds: arrowKinds, comment: comment, post: post, postFullname: postFullname, parentElement: parentElement, indentLines: indentLines, topCommentIdx: topCommentIdx, commentIndexMap: commentIndexMap, newCommentsLoaded: newCommentsLoaded, index: index)
            }
          } else {
            CommentLinkContent(highlightID: highlightID, seenComments: seenComments, showReplies: showReplies, arrowKinds: arrowKinds, indentLines: indentLines, lineLimit: lineLimit, post: post, comment: comment, winstonData: commentWinstonData, avatarsURL: avatarsURL, searchQuery: searchQuery, isMatch: isMatch, isCurrentMatch: comment.id == currentMatchId, collapsed: collapsed, highlightCurrentMatch: highlightCurrentMatch,parentShowReplies: parentShowReplies, parentArrowKinds: parentArrowKinds, parentIndentLines: parentIndentLines, parentLineLimit: parentLineLimit, parentComment: parentComment, parentAvatarsURL: parentAvatarsURL)
          }
        }
        .opacity((fadeSeenComments && seenComments?.contains(data.id) ?? false) ? 0.5 : 1)
        .onAppear {
          updateVisibleComments?(comment.id, true)
        }.onDisappear {
          updateVisibleComments?(comment.id, false)
        }
        
        if !collapsed && showReplies {
          ForEach(Array(children.enumerated()), id: \.element.id) { index, commentChild in
            let childrenCount = children.count
            if let childCommentWinstonData = commentChild.winstonData {
              CommentLink(post: post, arrowKinds: arrowKinds.map { $0.child } + [(childrenCount - 1 == index ? ArrowKind.curve : ArrowKind.straightCurve)], postFullname: postFullname, seenComments: seenComments, fadeSeenComments: fadeSeenComments, parentElement: .comment(comment), comment: commentChild, commentWinstonData: childCommentWinstonData, children: commentChild.childrenWinston, searchQuery: searchQuery, matchMap: matchMap, isMatch: matchMap[commentChild.id] != nil, currentMatchId: currentMatchId, topCommentIdx: topCommentIdx, commentIndexMap: commentIndexMap, highlightCurrentMatch: highlightCurrentMatch, updateVisibleComments: updateVisibleComments, newCommentsLoaded: newCommentsLoaded, parentShowReplies: showReplies, parentArrowKinds: arrowKinds, parentIndentLines: indentLines, parentLineLimit: lineLimit, parentComment: comment, parentAvatarsURL: avatarsURL, index: index)
                .id("\(commentChild.id)-\(childrenCount)")
            }
          }
        }
        
      }
      
    } else {
      Text("Oops")
    }
  }
}

struct CustomDisclosureGroupStyle: DisclosureGroupStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack {
      configuration.label
        .contentShape(Rectangle())
        .onTapGesture {
          withAnimation {
            configuration.isExpanded.toggle()
          }
        }
      if configuration.isExpanded {
        configuration.content
          .disclosureGroupStyle(self)
      }
    }
  }
}
