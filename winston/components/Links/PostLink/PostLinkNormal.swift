//
//  PostLinkNormal.swift
//  winston
//
//  Created by Igor Marcossi on 25/09/23.
//

import SwiftUI
import Defaults
import NukeUI

struct PostLinkNormalSelftext: View, Equatable {
  var selftext: String?
  var theme: ThemeText
  var body: some View {
    if let selftext {
      Text(selftext).lineLimit(3)
        .fontSize(theme.size, theme.weight.t)
        .foregroundColor(theme.color())
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    //      .id("body")
  }
}

struct PostLinkNormal: View, Equatable, Identifiable {
  static func == (lhs: PostLinkNormal, rhs: PostLinkNormal) -> Bool {
    return lhs.id == rhs.id && lhs.contentWidth == rhs.contentWidth && lhs.secondary == rhs.secondary && lhs.defSettings == rhs.defSettings && lhs.theme == rhs.theme
  }
  
  @Environment(\.contextPost) var post
  @Environment(\.contextSubreddit) var sub
  @Environment(\.contextPostWinstonData) var winstonData
  var id: String
  weak var controller: UIViewController?
  var theme: SubPostsListTheme
  var showSub = false
  var secondary = false
  let contentWidth: CGFloat
  let defSettings: PostLinkDefSettings
  var setCurrentOpenPost: ((Post) -> Void)?
    
  func markAsRead() async {
    Task(priority: .background) { await post.toggleSeen(true) }
  }
  
  func openPost() {
    setCurrentOpenPost?(post)
    Nav.to(.reddit(.post(post)))
  }
  
  func openSubreddit() {
    if let subName = post.data?.subreddit {
      setCurrentOpenPost?(post)

      withAnimation {
        Nav.to(.reddit(.subFeed(Subreddit(id: subName))))
      }
    }
  }
  
  func resetVideo(video: SharedVideo) {
    print("[VID] RESET \(video.url)")
    DispatchQueue.main.async {
      let newVideo: MediaExtractedType = .video(SharedVideo.get(url: video.url, size: video.size, resetCache: true, prevVideoId: video.id))
      post.winstonData?.extractedMedia = newVideo
      post.winstonData?.extractedMediaForcedNormal = newVideo
    }
  }
  
  func onDisappear() {
    Task(priority: .background) {
      if defSettings.readOnScroll {
        await post.toggleSeen(true, optimistic: true)
      }
      if defSettings.hideOnRead {
        await post.hide(true)
      }
    }
  }
  
  var over18: Bool { post.data?.over_18 ?? false }
  
  @ViewBuilder
  func mediaComponentCall() -> some View {
    if let data = post.data {
      if let extractedMedia = winstonData.extractedMedia {
        MediaPresenter(winstonData: winstonData, controller: controller, postTitle: data.formattedTitle(), badgeKit: data.badgeKit, avatarImageRequest: winstonData.avatarImageRequest, markAsSeen: !defSettings.lightboxReadsPost ? nil : markAsRead, cornerRadius: theme.theme.mediaCornerRadius, blurPostLinkNSFW: defSettings.blurNSFW, media: extractedMedia, over18: over18, compact: false, contentWidth: winstonData.postDimensions.mediaSize?.width ?? 0, maxMediaHeightScreenPercentage: defSettings.maxMediaHeightScreenPercentage, resetVideo: resetVideo)
          .allowsHitTesting(defSettings.isMediaTappable)
      }
    }
  }
  
  var body: some View {
    if let data = post.data {
//      let over18 = data.over_18 ?? false
      VStack(alignment: .leading, spacing: theme.theme.verticalElementsSpacing) {
        
        if theme.theme.showDivider && defSettings.dividerPosition == .top { SubsNStuffLine() }
        
        if defSettings.titlePosition == .bottom { mediaComponentCall() }
        
        VStack(alignment: .leading, spacing: theme.theme.verticalElementsSpacing / 2.5) {
          PostLinkTitle(attrString: winstonData.titleAttr, label: data.formattedTitle(), theme: theme.theme.titleText, size: winstonData.postDimensions.titleSize)
          
          if !(data.selftext?.isEmpty ?? true) && defSettings.showSelfText, let selftext = data.selftext {
            PostLinkNormalSelftext(selftext: MarkdownUtil.cleanupText(selftext, forBody: true), theme: theme.theme.bodyText)
              .lineSpacing(theme.theme.linespacing)
          }
        }
        
        if defSettings.titlePosition == .top { mediaComponentCall() }
        
        if theme.theme.showDivider && defSettings.dividerPosition == .bottom { SubsNStuffLine() }
        
        HStack {
          let seenCount = winstonData.getSeenCount()
          let newCommentsCount = seenCount == nil ? nil : data.num_comments - seenCount!
          
          BadgeView(avatarRequest: winstonData.avatarImageRequest, showAuthorOnPostLinks: defSettings.showAuthor, saved: data.badgeKit.saved, usernameColor: nil, author: data.badgeKit.author, fullname: data.badgeKit.authorFullname, userFlair: data.badgeKit.userFlair, created: data.badgeKit.created, avatarURL: nil, theme: theme.theme.badge, commentsCount: formatBigNumber(data.num_comments), newCommentsCount: newCommentsCount, votesCount: defSettings.showVotesCluster ? nil : formatBigNumber(data.ups), likes: data.likes, openSub: showSub ? openSubreddit : nil, subName: data.subreddit)
          
          Spacer()
          
          if defSettings.showVotesCluster { VotesCluster(votesKit: data.votesKit, voteAction: post.vote, showUpVoteRatio: defSettings.showUpVoteRatio).fontSize(22, .medium) }
          
        }
      }
      .postLinkStyle(post: post, sub: sub, theme: theme.theme, size: winstonData.postDimensions.size, secondary: secondary, openPost: openPost, readPostOnScroll: defSettings.readOnScroll, hideReadPosts: defSettings.hideOnRead)
      .swipyUI(onTap: openPost, actionsSet: defSettings.swipeActions, entity: post, secondary: secondary)
    }
  }
}

//let atr = NSTextAttachment()
//atr.
