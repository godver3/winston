//
//  Badge.swift
//  winston
//
//  Created by Igor Marcossi on 01/07/23.
//

import Foundation
import SwiftUI
import Defaults
import ObservedOptionalObject

struct BadgeView: View, Equatable {
  static let authorStatsSpacing: Double = 2
  static func == (lhs: BadgeView, rhs: BadgeView) -> Bool {
    lhs.extraInfo == rhs.extraInfo && lhs.theme == rhs.theme && lhs.avatarURL == rhs.avatarURL && lhs.saved == rhs.saved && lhs.id == rhs.id
  }
  
  @ObservedOptionalObject var post: Post?
  
  var id: String
  var saved = false
  var unseen = false
  var usernameColor: Color?
  var author: String
  var flair: String?
  var fullname: String? = nil
  var created: Double
  var avatarURL: String?
  var theme: BadgeTheme
  var commentTheme: CommentTheme?
  var extraInfo: [BadgeExtraInfo] = []
  var routerProxy: RouterProxy?
  var cs: ColorScheme
  
  let flagY: CGFloat = 16
  let delay: CGFloat = 0.4
    
  func openUser() {
    routerProxy?.router.path.append(User(id: author, api: RedditAPI.shared))
  }
  
  var body: some View {
    let showAvatar = theme.avatar.visible
        
    HStack(spacing: theme.spacing) {
      
      if saved && !showAvatar {
        Image(systemName: "bookmark.fill")
          .fontSize(16)
          .foregroundColor(.green)
          .transition(.scale.combined(with: .opacity))
      }
      
      if showAvatar {
        ZStack {
          Avatar(url: avatarURL, userID: author, fullname: fullname, theme: theme.avatar)
            .background(
              ZStack {
                Image(systemName: "bookmark.fill")
                  .foregroundColor(.green)
                  .offset(y: saved ? flagY : 0)
                
                Circle()
                  .fill(.gray)
                  .performantShadow(cornerRadius: 15, color: .black, opacity: 0.15, radius: 4, offsetY: 4, size: CGSize(width: 30, height: 30))
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .mask(
                    Image(systemName: "bookmark.fill")
                      .foregroundColor(.black)
                      .offset(y: saved ? flagY : 0)
                  )
                
                Circle()
                  .fill(.gray)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
              }
                .compositingGroup()
                .animation(.interpolatingSpring(stiffness: 150, damping: 12).delay(delay), value: saved)
            )
            .scaleEffect(1)
            .onTapGesture(perform: openUser)
        }
      }
      
      VStack(alignment: .leading, spacing: BadgeView.authorStatsSpacing) {
        
        HStack(alignment: .center, spacing: 6) {
          Text(author).font(.system(size: theme.authorText.size, weight: theme.authorText.weight.t)).foregroundColor(author == "[deleted]" ? .red : usernameColor ?? theme.authorText.color.cs(cs).color())
              .onTapGesture(perform: openUser)
          
          if unseen {
            ZStack {
              Circle()
                .fill(commentTheme?.unseenDot.cs(cs).color() ?? .red)
                .frame(width: 6, height: 6)
              Circle()
                .fill(commentTheme?.unseenDot.cs(cs).color() ?? .red)
                .frame(width: 8, height: 8)
                .blur(radius: 8)
            }
          }
          
          if let f = flair?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if !f.isEmpty {
              let colonIndex = f.lastIndex(of: ":")
              let flairWithoutEmoji = String(f[(f.contains(":") ? f.index(colonIndex!, offsetBy: min(2, max(0, f.count - f.distance(from: f.startIndex, to: colonIndex!)))) : f.startIndex)...])
              if !flairWithoutEmoji.isEmpty {
                // TODO Load flair emojis via GET /api/v1/{subreddit}/emojis/{emoji_name}
                Text(flairWithoutEmoji).font(.system(size: theme.flairText.size, weight: theme.flairText.weight.t)).lineLimit(1).foregroundColor(theme.flairText.color.cs(cs).color()).padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)).background(theme.flairBackground.cs(cs).color()).clipShape(Capsule())
              }
            }
          }
        }
        
        HStack(alignment: .center, spacing: 6) {
          ForEach(extraInfo, id: \.self){ elem in
            HStack(alignment: .center, spacing: 2){
              Image(systemName: elem.systemImage)
                .foregroundColor(elem.iconColor ?? theme.statsText.color.cs(cs).color())
              Text(elem.text)
              
              if elem.type == "comments", let seenComments = post?.data?.winstonSeenCommentCount, let totalComments = Int(elem.text) {
                let unseenComments = totalComments - seenComments
                if unseenComments > 0 {
                  Text("(\(Int(unseenComments)))").foregroundColor(.accentColor)
                }
              }
            }
          }
          
          HStack(alignment: .center, spacing: 2) {
            Image(systemName: "hourglass.bottomhalf.filled")
            Text(timeSince(Int(created)))
          }
        }
        .foregroundColor(theme.statsText.color.cs(cs).color())
        .font(.system(size: theme.statsText.size, weight: theme.statsText.weight.t))
        .compositingGroup()
      }
    }
    .scaleEffect(1)
    .animation(showAvatar ? nil : spring.delay(delay), value: saved)
  }
}


struct Badge: View, Equatable {
  static func == (lhs: Badge, rhs: Badge) -> Bool {
    lhs.extraInfo == rhs.extraInfo && lhs.theme == rhs.theme && lhs.avatarURL == rhs.avatarURL
  }
  
  @ObservedOptionalObject var post: Post?
  var usernameColor: Color?
  var avatarURL: String?
  var theme: BadgeTheme
  var extraInfo: [BadgeExtraInfo] = []
  @EnvironmentObject private var routerProxy: RouterProxy
  @Environment(\.colorScheme) private var cs: ColorScheme

  var body: some View {
    if let data = post?.data {
      BadgeView(post: post, id: data.id, usernameColor: usernameColor, author: data.author, flair: data.author_flair_text, fullname: data.author_fullname, created: data.created, avatarURL: avatarURL, theme: theme, extraInfo: extraInfo, routerProxy: routerProxy, cs: cs)
    }
  }
}

struct BadgeComment: View, Equatable {
  static func == (lhs: BadgeComment, rhs: BadgeComment) -> Bool {
    lhs.extraInfo == rhs.extraInfo && lhs.theme == rhs.theme && lhs.avatarURL == rhs.avatarURL && lhs.comment.data?.id == rhs.comment.data?.id
  }
  
  @ObservedObject var comment: Comment
  var unseen: Bool
  var usernameColor: Color?
  var avatarURL: String?
  var theme: BadgeTheme
  var commentTheme: CommentTheme?
  var extraInfo: [BadgeExtraInfo] = []
  @EnvironmentObject private var routerProxy: RouterProxy
  @Environment(\.colorScheme) private var cs: ColorScheme
  
  var body: some View {
    if let data = comment.data, let author = data.author, let created = data.created {
      BadgeView(id: data.id, unseen: unseen, usernameColor: usernameColor, author: author, flair: data.author_flair_text, fullname: data.author_fullname, created: created, avatarURL: avatarURL, theme: theme, commentTheme: commentTheme, extraInfo: extraInfo, routerProxy: routerProxy, cs: cs)
      
    }
  }
}

struct BadgeExtraInfo: Hashable {
  var type: String
  var systemImage: String = ""
  var text: String
  //  var textColor: Color = Color.primary
  var iconColor: Color?
}


struct PresetBadgeExtraInfo {
  
  init(){}
  
  func upvotesExtraInfo(data: PostData) -> BadgeExtraInfo{
    //    let upvoted = data.likes != nil && data.likes!
    //    let downvoted = data.likes != nil && !data.likes!
    //    return BadgeExtraInfo(systemImage: upvoted  ? "arrow.up" : (downvoted ? "arrow.down" : "arrow.up"), text: "\(formatBigNumber(data.ups))",textColor: upvoted ? .orange : (downvoted ? .blue : .primary), iconColor:  upvoted ? .orange : (downvoted ? .blue : .primary))
    return BadgeExtraInfo(type: "ups", systemImage: "arrow.up", text: "\(formatBigNumber(data.ups))")
  }
  
  func commentsExtraInfo(data: PostData) -> BadgeExtraInfo{
    return BadgeExtraInfo(type: "comments", systemImage: "message.fill", text: "\(formatBigNumber(data.num_comments))")
  }
  
}
