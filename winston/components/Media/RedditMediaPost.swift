//
//  RedditMediaPost.swift
//  winston
//
//  Created by Igor Marcossi on 31/07/23.
//

import SwiftUI
import Combine

enum ThingType {
  case post(Post)
  case comment(Comment)
  case user(User)
  case subreddit(Subreddit)
}

class ThingEntityCache: ObservableObject {
  static var shared = ThingEntityCache()
  @Published var thingEntities: [RedditURLType:ThingType] = [:]
  
  func load(_ thing: RedditURLType, redditAPI: RedditAPI) {
    if thingEntities[thing] != nil { return }
    Task(priority: .background) {
      switch thing {
      case .comment(let id, _, _):
        if let data = await RedditAPI.shared.fetchInfo(fullnames: ["\(Comment.prefix)_\(id)"]) {
          await MainActor.run { withAnimation {
            switch data {
            case .comment(let listing):
              if let data = listing.data?.children?[0].data {
                thingEntities[thing] = .comment(Comment(data: data, api: RedditAPI.shared))
              }
            default:
              break
            }
          } }
        }
      case .post(let id, _):
        if let data = await RedditAPI.shared.fetchInfo(fullnames: ["\(Post.prefix)_\(id)"]) {
          await MainActor.run { withAnimation {
            switch data {
            case .post(let listing):
              if let data = listing.data?.children?[0].data {
                thingEntities[thing] = .post(Post(data: data, api: RedditAPI.shared))
              }
            default:
              break
            }
          } }
        }
      case .user(let username):
        if let data = await RedditAPI.shared.fetchUser(username) {
          await MainActor.run { withAnimation {
            thingEntities[thing] = .user(User(data: data, api: RedditAPI.shared))
          } }
        }
      case .subreddit(name: let name):
        Task(priority: .background) {
          if let data = (await RedditAPI.shared.fetchSub(name))?.data  {
            await MainActor.run { withAnimation {
              thingEntities[thing] = .subreddit(Subreddit(data: data, api: RedditAPI.shared))
            } }
          }
        }
      default:
        break
      }
    }
  }
}

struct RedditMediaPost: View {
  var thing: RedditURLType
  @ObservedObject private var thingEntitiesCache = ThingEntityCache.shared
  static let height: CGFloat = 88
  
  
  var body: some View {
    HStack(spacing: 16) {
      if let entity = thingEntitiesCache.thingEntities[thing] {
        switch entity {
        case .comment(let comment):
          VStack {
            //            ShortCommentPostLink(comment: comment)
            CommentLink(showReplies: false, comment: comment)
//              .equatable()
          }
          .padding(.vertical, 8)
        case .post(let post):
          ShortPostLink(noHPad: true, post: post)
        case .user(let user):
          UserLinkContainer(noHPad: true, user: user)
        case .subreddit(let subreddit):
          SubredditLinkContainer(sub: subreddit)
        }
      } else {
        ProgressView()
          .onAppear {
            thingEntitiesCache.load(thing, redditAPI: RedditAPI.shared)
          }
      }
    }
    .frame(maxWidth: .infinity, minHeight: RedditMediaPost.height, maxHeight: RedditMediaPost.height)
    .padding(.horizontal, 8)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.primary.opacity(0.05)))

  }
}
