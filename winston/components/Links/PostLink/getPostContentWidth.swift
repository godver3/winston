//
//  getPostContentWidth.swift
//  winston
//
//  Created by Igor Marcossi on 24/09/23.
//

import Foundation
import SwiftUI
import Defaults

func getPostContentWidth(contentWidth: Double = UIScreen.screenWidth, secondary: Bool = false) -> CGFloat {
  let selectedTheme = Defaults[.themesPresets].first(where: { $0.id == Defaults[.selectedThemeID] }) ?? defaultTheme
  let theme = selectedTheme.postLinks.theme
  var value: CGFloat = 0
  if IPAD {
    value = (contentWidth / 2) - ((theme.innerPadding.horizontal * (secondary ? 2 : 1)) * 2) - 24
  } else {
    value = contentWidth - (((theme.innerPadding.horizontal * (secondary ? 2 : 1)) + theme.outerHPadding) * 2)
  }
  return value
}

struct PostDimensions: Hashable, Equatable {
  let contentWidth: Double
  let titleSize: CGSize
  var bodySize: CGSize? = nil
  var urlTagHeight: Double? = nil
  var mediaSize: CGSize? = nil
  var dividerSize: CGSize
  var badgeSize: CGSize
  var spacingHeight: Double
  var padding: CGSize { self.theme.innerPadding.toSize() }
  var theme: PostLinkTheme
  var compact: Bool
  var size: CGSize {
    
    let compactVSpacing = self.spacingHeight / 2
    let tagHeight = urlTagHeight == nil ? 0 : (compactVSpacing / 2) + (self.urlTagHeight ?? 0)
    let compactHeight = max(self.titleSize.height + compactVSpacing + self.badgeSize.height + tagHeight, (mediaSize?.height ?? 0)) + dividerSize.height + compactVSpacing
    let normalHeight = self.titleSize.height + (self.bodySize?.height ?? 0) + (self.mediaSize?.height ?? 0) + self.dividerSize.height + self.badgeSize.height + self.spacingHeight
    return CGSize(
      width: self.contentWidth + (self.padding.width * 2),
      height: (self.compact ? compactHeight : normalHeight) + (self.padding.height * 2)
    )
  }
  
  init(contentWidth: Double, compact: Bool? = nil, theme: PostLinkTheme? = nil, titleSize: CGSize, bodySize: CGSize? = nil, urlTagHeight: Double? = nil, mediaSize: CGSize? = nil, dividerSize: CGSize, badgeSize: CGSize, spacingHeight: Double) {
    self.contentWidth = contentWidth
    self.compact = compact ?? Defaults[.compactMode]
    self.theme = theme ?? getEnabledTheme().postLinks.theme
    self.titleSize = titleSize
    self.bodySize = bodySize
    self.urlTagHeight = urlTagHeight
    self.mediaSize = mediaSize
    self.dividerSize = dividerSize
    self.badgeSize = badgeSize
    self.spacingHeight = spacingHeight
  }
}

func getPostDimensions(post: Post, columnWidth: Double = UIScreen.screenWidth, secondary: Bool = false, theme: WinstonTheme? = nil) -> PostDimensions? {
  if let data = post.data {
    let selectedTheme = theme ?? getEnabledTheme()
    let compact = Defaults[.compactMode]
    let maxDefaultHeight: CGFloat = Defaults[.maxPostLinkImageHeightPercentage]
    let maxHeight: CGFloat = (maxDefaultHeight / 100) * (UIScreen.screenHeight)
    let extractedMedia = post.winstonData?.extractedMedia
    let compactImgSize = scaledCompactModeThumbSize()
    let theme = selectedTheme.postLinks.theme
    let postGeneralSpacing = theme.verticalElementsSpacing + theme.linespacing
    let title = data.title
    let body = data.selftext
    
    var ACC_titleHeight: Double = 0
    var ACC_bodyHeight: Double = 0
    
    var contentWidth: CGFloat = 0
    if IPAD {
      contentWidth = (columnWidth / 2) - ((theme.innerPadding.horizontal * (secondary ? 2 : 1)) * 2) - 24
    } else {
      contentWidth = columnWidth - (((theme.innerPadding.horizontal * (secondary ? 2 : 1)) + theme.outerHPadding) * 2)
    }
    
    var ACC_mediaSize: CGSize = .zero
    let compactMediaSize = CGSize(width: compactImgSize, height: compactImgSize)
    
    if let extractedMedia = extractedMedia {
      if compact { ACC_mediaSize = compactMediaSize } else {
        func defaultMediaSize(_ size: CGSize) -> CGSize {
          let sourceHeight = size.height == 0 ? post.winstonData?.postDimensions?.mediaSize?.height ?? 0 : size.height
          let sourceWidth = size.width == 0 ? post.winstonData?.postDimensions?.mediaSize?.width ?? 0 : size.width
          let propHeight = (contentWidth * sourceHeight) / sourceWidth
          let finalHeight = maxDefaultHeight != 110 ? Double(min(maxHeight, propHeight)) : Double(propHeight)
          return CGSize(width: contentWidth, height: finalHeight)
        }
        
        switch extractedMedia {
        case .image(let mediaExtracted):
          ACC_mediaSize = defaultMediaSize(mediaExtracted.size)
        case .video(let video):
          ACC_mediaSize = defaultMediaSize(video.size)
        case .gallery(let mediasExtracted):
          let size = compact ? scaledCompactModeThumbSize() : ((contentWidth - 8) / 2)
          ACC_mediaSize = mediasExtracted.count == 2 ? CGSize(width: contentWidth, height: size) : CGSize(width: contentWidth, height: (size * 2) + ImageMediaPost.gallerySpacing)
        case .youtube(_, let size):
          let actualHeight = (contentWidth * CGFloat(size.height)) / CGFloat(size.width)
          ACC_mediaSize = CGSize(width: contentWidth, height: actualHeight)
        case .link(_):
          ACC_mediaSize = CGSize(width: contentWidth, height: PreviewLinkContentRaw.height)
        case .repost(let repost):
          if let repostSize = repost.winstonData?.postDimensions {
            ACC_mediaSize = repostSize.size
          }
          //        if let repostSize = getPostDimensions(post: repost, secondary: true) {
          //          ACC_mediaSize = repostSize.size
          //        }
        case .post(_, _):
          if !compact { ACC_mediaSize = CGSize(width: contentWidth, height: RedditMediaPost.height) }
          break
        case .comment(_, _, _):
          if !compact { ACC_mediaSize = CGSize(width: contentWidth, height: RedditMediaPost.height) }
          break
        case .subreddit(_):
          if !compact { ACC_mediaSize = CGSize(width: contentWidth, height: RedditMediaPost.height) }
          break
        case .user(_):
          if !compact { ACC_mediaSize = CGSize(width: contentWidth, height: RedditMediaPost.height) }
          break
        }
      }
    }
    
    var urlTagHeight: Double = 0
    if compact, let extractedMedia = extractedMedia, case .link(_) = extractedMedia {
      urlTagHeight = OnlyURL.height
    }
    
    
    let compactTitleWidth = postGeneralSpacing + VotesCluster.verticalWidth + (extractedMedia == nil ? 0 : postGeneralSpacing + compactMediaSize.width)
    let titleContentWidth = contentWidth - (compact ? compactTitleWidth : 0)
    
    ACC_titleHeight = round(NSString(string: title).boundingRect(with: CGSize(width: titleContentWidth, height: .infinity), options: [.usesLineFragmentOrigin], attributes: [.font: UIFont.systemFont(ofSize: theme.titleText.size, weight: theme.titleText.weight.ut)], context: nil).height)
    
    if !body.isEmpty && !compact {
      ACC_bodyHeight = round(NSString(string: body).boundingRect(with: CGSize(width: contentWidth, height: (theme.bodyText.size * 1.2) * 3), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: [.font: UIFont.systemFont(ofSize: theme.bodyText.size, weight: theme.bodyText.weight.ut)], context: nil).height)
    }
    

    
    ACC_mediaSize.width = round(ACC_mediaSize.width)
    ACC_mediaSize.height = round(ACC_mediaSize.height)
    
    let ACC_SubDividerHeight = SubsNStuffLine.height
    
    let badgeAvatarHeight = theme.badge.avatar.visible ? theme.badge.avatar.size : 0
    let badgeAuthorHeight = theme.badge.authorText.size * 1.2
    let badgeStatsFontHeight = theme.badge.statsText.size * 1.2
    let badgeAuthorStatsSpacing = BadgeView.authorStatsSpacing
    
    let ACC_badgeHeight = round(max(badgeAvatarHeight, badgeAuthorHeight + badgeStatsFontHeight + badgeAuthorStatsSpacing, 34))
    
    
    
    let theresTitle = true
    let theresSelftext = !compact && !data.selftext.isEmpty
    let theresMedia = extractedMedia != nil
    let theresSubDivider = true
    let theresBadge = true
    let elements = [theresTitle, theresSelftext, !compact && theresMedia, theresSubDivider, theresBadge]
    let ACC_allSpacingsHeight = Double(elements.filter { $0 }.count - 1) * postGeneralSpacing
    
//    let ACC_verticalPadding = theme.innerPadding.vertical * 2
    
//    let totalHeight = ACC_titleHeight + ACC_bodyHeight + ACC_mediaSize.height + ACC_SubDividerHeight + ACC_badgeHeight + ACC_verticalPadding + ACC_allSpacingsHeight
    
    let dimensions = PostDimensions(
      contentWidth: contentWidth,
      theme: theme,
      titleSize: CGSize(width: titleContentWidth, height: ACC_titleHeight),
      bodySize: !theresSelftext || compact ? nil : CGSize(width: contentWidth, height: ACC_bodyHeight),
      urlTagHeight: urlTagHeight,
      mediaSize: !theresMedia ? nil : compact ? compactMediaSize : CGSize(width: contentWidth, height: ACC_mediaSize.height),
      dividerSize: CGSize(width: contentWidth, height: ACC_SubDividerHeight),
      badgeSize: CGSize(width: contentWidth, height: ACC_badgeHeight),
      spacingHeight: ACC_allSpacingsHeight
    )

    return dimensions
  }
  return nil
}
