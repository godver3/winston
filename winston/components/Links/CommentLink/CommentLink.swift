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

struct CommentLink: View, Equatable {
  static func == (lhs: CommentLink, rhs: CommentLink) -> Bool {
    lhs.post == rhs.post &&
    lhs.subreddit == rhs.subreddit &&
    lhs.indentLines == rhs.indentLines &&
    lhs.highlightID == rhs.highlightID &&
    lhs.searchQuery == rhs.searchQuery &&
    lhs.isMatch == rhs.isMatch &&
    lhs.currentMatchId == rhs.currentMatchId &&
    lhs.fadeSeenComments == rhs.fadeSeenComments &&
    lhs.comment == rhs.comment &&
    lhs.children.count == rhs.children.count &&
    (lhs.children.count > 0 ? lhs.children[0] == rhs.children[0] : true)
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
  var matchMap: [String: Bool] = [:]
  var isMatch: Bool = false
  
  var currentMatchId: String? = nil
  var newCommentsLoaded: (() -> Void)?
  var updateVisibleComments: ((String, Bool) -> Void)?
  
  var isLast: Bool = false
  var commentLinkMore: CommentLinkMore? = nil
  
  func childrenContainsMatch (_ comment: Comment)  -> Bool {
    if matchMap[comment.id] ?? false {
      return true
    }
    
    for child in comment.childrenWinston {
      if childrenContainsMatch(child) {
        return true
      }
    }
    
    return false
  }
  
  var body: some View {
    if let data = comment.data {
      let collapsed = data.collapsed ?? false
      Group {
        Group {
          if let kind = comment.kind, kind == "more" {
            if comment.id == "_" {
              if let post = post {
                CommentLinkFull(post: post, arrowKinds: arrowKinds, comment: comment, indentLines: indentLines)
              }
            } else {
              CommentLinkMore(arrowKinds: arrowKinds, comment: comment, post: post, postFullname: postFullname, parentElement: parentElement, indentLines: indentLines, isLast: isLast, newCommentsLoaded: newCommentsLoaded)
            }
          } else {
            CommentLinkContent(highlightID: highlightID, seenComments: seenComments, showReplies: showReplies, arrowKinds: arrowKinds, indentLines: indentLines, lineLimit: lineLimit, post: post, comment: comment, winstonData: commentWinstonData, avatarsURL: avatarsURL, searchQuery: searchQuery, isMatch: isMatch, selfOrChildIsMatch: isMatch || childrenContainsMatch(comment), isCurrentMatch: comment.id == currentMatchId)
          }
        }
          .opacity((fadeSeenComments && seenComments?.contains(data.id) ?? false) ? 0.6 : 1)
          .onAppear {
            updateVisibleComments?(comment.id, true)
          }.onDisappear {
            updateVisibleComments?(comment.id, false)
          }
        
        if !collapsed && showReplies {
          ForEach(Array(children.enumerated()), id: \.element.id) { index, commentChild in
            let childrenCount = children.count
            if let childCommentWinstonData = commentChild.winstonData {
              CommentLink(post: post, arrowKinds: arrowKinds.map { $0.child } + [(childrenCount - 1 == index ? ArrowKind.curve : ArrowKind.straightCurve)], postFullname: postFullname, seenComments: seenComments, fadeSeenComments: fadeSeenComments, parentElement: .comment(comment), comment: commentChild, commentWinstonData: childCommentWinstonData, children: commentChild.childrenWinston, searchQuery: searchQuery, matchMap: matchMap, isMatch: matchMap[commentChild.id] ?? false, currentMatchId: currentMatchId, newCommentsLoaded: newCommentsLoaded, updateVisibleComments: updateVisibleComments)
                .id(commentChild.id)
              //                .equatable()
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
