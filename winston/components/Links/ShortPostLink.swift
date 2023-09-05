//
//  ShortPostLink.swift
//  winston
//
//  Created by Igor Marcossi on 29/07/23.
//

import SwiftUI
import Defaults

struct ShortPostLink: View {
  var noHPad = false
  var post: Post
  @StateObject private var attrStrLoader = AttributedStringLoader()
  @Default(.preferenceShowPostsAvatars) private var preferenceShowPostsAvatars
  @EnvironmentObject private var routerProxy: RouterProxy
  var body: some View {
    if let data = post.data {
      VStack(alignment: .leading) {
        Text("\(data.title.escape)")
          .fontSize(18, .semibold)
        Text((data.selftext).md()).lineLimit(2)
          .fontSize(15).opacity(0.75)
          .onAppear { attrStrLoader.load(str: data.selftext) }
        HStack {
          if let fullname = data.author_fullname {
            Badge(showAvatar: preferenceShowPostsAvatars, author: data.author, fullname: fullname, created: data.created, extraInfo: [PresetBadgeExtraInfo().commentsExtraInfo(data: data), PresetBadgeExtraInfo().upvotesExtraInfo(data: data)])
          }
          Spacer()
          FlairTag(text: "r/\(data.subreddit)", color: .blue)
            .highPriorityGesture(TapGesture().onEnded {
              routerProxy.router.path.append(SubViewType.posts(Subreddit(id: data.subreddit, api: post.redditAPI)))
            })
        }
      }
      .padding(.horizontal, noHPad ? 0 : 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RR(20, noHPad ? .clear : .listBG))
      .onTapGesture {
        routerProxy.router.path.append(PostViewPayload(post: post, postSelfAttr: attrStrLoader.data, sub: Subreddit(id: data.subreddit, api: post.redditAPI)))
      }
    }
  }
}
