//
//  ShortCommentPostLink.swift
//  winston
//
//  Created by Igor Marcossi on 04/07/23.
//

import SwiftUI
import Defaults
struct ShortCommentPostLink: View {
  @EnvironmentObject private var routerProxy: RouterProxy
  var comment: Comment
  @State var openedPost = false
  @State var openedSub = false
  @Default(.coloredCommentNames) var coloredCommentNames
  var body: some View {
    if let data = comment.data, let _ = data.link_id, let _ = data.subreddit {
      //      Button {
      
      //      } label: {
      VStack(alignment: .leading, spacing: 6) {
        Text(data.link_title ?? "Error")
          .fontSize(15, .medium)
          .opacity(0.75)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
//          .onAppear { attrStrLoader.load(str: data.selftext) }
        
        VStack(alignment: .leading, spacing: 2) {
          if let author = data.author {
            (Text(author).font(.system(size: 13, weight: .semibold)).foregroundColor(coloredCommentNames ? .blue : .primary))
              .onTapGesture { routerProxy.router.path.append(User(id: data.author!, api: comment.redditAPI)) }
          }
          
          if let subreddit = data.subreddit {
            (Text("on ").font(.system(size: 13, weight: .medium)).foregroundColor(.primary.opacity(0.5)) + Text("r/\(subreddit)").font(.system(size: 14, weight: .semibold)).foregroundColor(.primary.opacity(0.75)))
              .onTapGesture { routerProxy.router.path.append(SubViewType.posts(Subreddit(id: data.subreddit!, api: comment.redditAPI))) }
          }
        }
      }
      .multilineTextAlignment(.leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RR(14, .secondary.opacity(0.075))
          .onTapGesture {
            openedPost = true
          }
      )
      .mask(RR(14, .black))
      .contentShape(Rectangle())
      .highPriorityGesture (
        TapGesture().onEnded {
          routerProxy.router.path.append(PostViewPayload(post: Post(id: data.link_id!, api: comment.redditAPI), sub: Subreddit(id: data.subreddit!, api: comment.redditAPI)))
        }
      )
      .foregroundColor(.primary)
      .multilineTextAlignment(.leading)
    } else {
      Text("Oops")
    }
  }
}
