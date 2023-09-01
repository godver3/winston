//
//  UserView.swift
//  winston
//
//  Created by Igor Marcossi on 01/07/23.
//

import SwiftUI
import NukeUI

//enum UserViewSections: Int {
//  case
//}

struct UserView: View {
  @StateObject var user: User
  @State private var loading = true
  @State private var lastActivities: [Either<PostData, CommentData>]?
  @State private var contentWidth: CGFloat = 0
  @State private var lastItemId: String? = nil

  
  func refresh() async {
    loading = true
    
    await user.refetchUser()
    if let data = await user.refetchOverview() {
      await MainActor.run {
        withAnimation {
          lastActivities = data
          loading = false
        }
      }
      
      await user.redditAPI.updateAvatarURLCacheFromOverview(subjects: data)
      
      if let lastItem = data.last {
        lastItemId = getItemId(for: lastItem)
      }
    }
  }
  
  func loadNextData() {
    loading = true
    Task {
      if let lastId = lastItemId, let overviewData = await user.refetchOverview(lastId) {
        await MainActor.run {
          withAnimation {
            lastActivities?.append(contentsOf: overviewData)
            loading = false
          }
        }

        if let lastItem = overviewData.last {
          lastItemId = getItemId(for: lastItem)
        }
      }
    }
  }
  
  func getItemId(for item: Either<PostData, CommentData>) -> String {
    // As per API doc: https://www.reddit.com/dev/api/#GET_user_{username}_overview
    switch item {
      case .first(let post):
      return "\(Post.prefix)_\(post.id)"
        
      case .second(let comment):
      return "\(Comment.prefix)_\(comment.id)"
    }
  }

  var body: some View {
    List {
      if let data = user.data {
        Group {
          VStack(spacing: 16) {
            ZStack {
              if let bannerImgFull = data.subreddit?.banner_img, !bannerImgFull.isEmpty, let bannerImg = URL(string: String(bannerImgFull.split(separator: "?")[0])) {
                URLImage(url: bannerImg)
                .scaledToFill()
                .frame(width: contentWidth, height: 160)
                .mask(RR(16, .black))
              }
              if let iconFull = data.subreddit?.icon_img, iconFull != "", let icon = URL(string: String(iconFull.split(separator: "?")[0])) {
                
                URLImage(url: icon)
                .scaledToFill()
                .frame(width: 125, height: 125)
                .mask(Circle())
                .offset(y: data.subreddit?.banner_img == "" || data.subreddit?.banner_img == nil ? 0 : 80)
              }
            }
            .frame(maxWidth: .infinity)
            .background(
              GeometryReader { geo in
                Color.clear.onAppear { contentWidth = geo.size.width }
              }
            )
            .padding(.bottom, data.subreddit?.banner_img == "" || data.subreddit?.banner_img == nil ? 0 : 78)
            
            if let description = data.subreddit?.public_description {
              Text((description).md())
                .fontSize(15)
            }
            
            VStack {
              HStack {
                if let postKarma = data.link_karma {
                  DataBlock(icon: "highlighter", label: "Post karma", value: "\(formatBigNumber(postKarma))")
                    .transition(.opacity)
                }
                
                if let commentKarma = data.comment_karma {
                  DataBlock(icon: "checkmark.message.fill", label: "Comment karma", value: "\(formatBigNumber(commentKarma))")
                    .transition(.opacity)
                }
              }
              if let created = data.created {
                DataBlock(icon: "star.fill", label: "User since", value: "\(Date(timeIntervalSince1970: TimeInterval(created)).toFormat("MMM dd, yyyy"))")
                  .transition(.opacity)
              }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .transition(.opacity)
          }
          
          Text("Last activities")
            .fontSize(20, .bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
          
          if let lastActivities = lastActivities {
            ForEach(Array(lastActivities.enumerated()), id: \.self.element.hashValue) { i, item in
              VStack(spacing: 0) {
                switch item {
                case .first(let post):
                  PostLink(post: Post(data: post, api: user.redditAPI), sub: Subreddit(id: post.subreddit, api: user.redditAPI), showSub: true)
                case .second(let comment):
                  VStack {
                    ShortCommentPostLink(comment: Comment(data: comment, api: user.redditAPI))
                    CommentLink(lineLimit: 3, showReplies: false, comment: Comment(data: comment, api: user.redditAPI))
                      .allowsHitTesting(false)
                  }
                  .padding(.horizontal, 12)
                  .padding(.top, 12)
                  .padding(.bottom, 10)
                  .background(RR(20, .listBG))
                }
              }
              .onAppear { if lastActivities.count > 0 && (Int(Double(lastActivities.count) * 0.75) == i) && !loading { loadNextData() }}
            }
          }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .transition(.opacity)
      }
    }
    .loader(loading)
    .background(Color(UIColor.systemGroupedBackground))
    .scrollContentBackground(.hidden)
    .listStyle(.plain)
    .refreshable {
      await refresh()
    }
    .navigationTitle(user.data?.name ?? "Loading...")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      Task(priority: .background) {
        if user.data == nil || lastActivities == nil {
          await refresh()
        }
      }
    }
  }
}

//struct UserView_Previews: PreviewProvider {
//    static var previews: some View {
//        UserView()
//    }
//}
