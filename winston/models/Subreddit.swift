//
//  SubredditData.swift
//  winston
//
//  Created by Igor Marcossi on 26/06/23.
//

import Foundation
import Defaults
import SwiftUI


typealias Subreddit = GenericRedditEntity<SubredditData>

extension Subreddit {
  static var prefix = "t5"
  convenience init(data: T, api: RedditAPI) {
    self.init(data: data, api: api, typePrefix: "\(Subreddit.prefix)_")
  }
  
  convenience init(id: String, api: RedditAPI) {
    self.init(id: id, api: api, typePrefix: "\(Subreddit.prefix)_")
  }
  
  /// Add a subreddit to the local like list
  /// This is a seperate list from reddits liked intenden for usage with subreddits a user wants to favorite but not subscribe to
  /// returns true if added to favorites and false if removed
  func localFavoriteToggle() -> Bool {
    @Default(.likedButNotSubbed) var likedButNotSubbed
    // If the user is not subscribed
    
    // If its already in liked remove it
    if likedButNotSubbed.contains(self) {
      likedButNotSubbed = likedButNotSubbed.filter{ $0.id != self.id }
      return false
    } else { // Else add it
      likedButNotSubbed.append(self)
      return true
    }
  }
  
  func favoriteToggle() async {
    if let favoritedStatus = data?.user_has_favorited, let name = data?.display_name {
      await MainActor.run{
        withAnimation {
          data?.user_has_favorited = !favoritedStatus
        }
      }
      
      let result = await redditAPI.favorite(!favoritedStatus, subName: name)
      if !result {
        await MainActor.run {
          
          withAnimation {
            data?.user_has_favorited = favoritedStatus
          }
        }
      }
    }
  }
  
  
  
  func subscribeToggle(optimistic: Bool = false) async {
    if let data = data {
      let subscribedStatus = Defaults[.subreddits].contains(where: { $0.data?.id == self.id })
      let likedButNotSubbed = Defaults[.likedButNotSubbed]
      if optimistic {
        await MainActor.run {
          @Default(.likedButNotSubbed) var likedButNotSubbed
          withAnimation(.default) {
            if subscribedStatus { // when unsubscribe
              Defaults[.subreddits] = Defaults[.subreddits].filter { sub in
                sub.data?.id != self.id
              }
              likedButNotSubbed = likedButNotSubbed.filter{ $0.id != self.id }
            } else {
              Defaults[.subreddits].append(ListingChild(kind: "t5", data: data))
            }
          }
        }
      }
      let result = await redditAPI.subscribe(subscribedStatus ? .unsub : .sub, subFullname: data.name)
      if result {
        if !optimistic {
          await MainActor.run {
            //            doThisAfter(0) {
            if subscribedStatus {
              Defaults[.subreddits] = Defaults[.subreddits].filter { sub in
                sub.data?.id != self.id
              }
            } else {
              Defaults[.subreddits].append(ListingChild(kind: "t5", data: data))
            }
            //            }
          }
        }
      } else {
        if optimistic {
          await MainActor.run {
            withAnimation(spring) {
              if !subscribedStatus {
                Defaults[.subreddits] = Defaults[.subreddits].filter { sub in
                  sub.data?.id != self.id
                }
              } else if !Defaults[.subreddits].contains(where: { $0.data?.id == self.id }) {
                Defaults[.subreddits].append(ListingChild(kind: "t5", data: data))
              }
            }
          }
        }
      }
      
      if !subscribedStatus && likedButNotSubbed.contains(self){
        await MainActor.run{
          _ = self.localFavoriteToggle()
        }
        await self.favoriteToggle()
      }
    }
  }
  
  func getFlairs() async -> [Flair]? {
    if let data = (await redditAPI.getFlairs(data?.display_name ?? id)) {
      await MainActor.run {
        withAnimation {
          self.data?.winstonFlairs = data
        }
      }
    }
    return nil
  }
  
  func refreshSubreddit() async {
    if let data = (await redditAPI.fetchSub(data?.display_name ?? id))?.data {
      await MainActor.run {
        withAnimation {
          self.data = data
        }
      }
    }
  }
  
  func fetchRules() async -> RedditAPI.FetchSubRulesResponse? {
    if let data = await redditAPI.fetchSubRules(data?.display_name ?? id) {
      return data
    }
    return nil
  }
  
  func fetchPosts(sort: SubListingSortOption = .best, after: String? = nil) async -> ([Post]?, String?)? {
    if let response = await redditAPI.fetchSubPosts(data?.url ?? (id == "home" ? "" : id), sort: sort, after: after), let data = response.0 {
      return (Post.initMultiple(datas: data.compactMap { $0.data }, api: redditAPI), response.1)
    }
    return nil
  }
}

//struct SubredditData: GenericRedditEntityDataType, _DefaultsSerializable {
//
//}

struct SubredditData: Codable, GenericRedditEntityDataType, Defaults.Serializable {
  let user_flair_background_color: String?
  var submit_text_html: String?
  let restrict_posting: Bool?
  var user_is_banned: Bool?
  let free_form_reports: Bool?
  let wiki_enabled: Bool?
  let user_is_muted: Bool?
  let user_can_flair_in_sr: Bool?
  let display_name: String?
  let header_img: String?
  let title: String?
  let allow_galleries: Bool?
  let icon_size: [Int]?
  let primary_color: String?
  let active_user_count: Int?
  let icon_img: String?
  let display_name_prefixed: String?
  let accounts_active: Int?
  let public_traffic: Bool?
  let subscribers: Int?
  let name: String
  let quarantine: Bool?
  let hide_ads: Bool?
  let prediction_leaderboard_entry_type: String?
  let emojis_enabled: Bool?
  let advertiser_category: String?
  var public_description: String
  let comment_score_hide_mins: Int?
  let allow_predictions: Bool?
  var user_has_favorited: Bool?
  let user_flair_template_id: String?
  let community_icon: String?
  let banner_background_image: String?
  let original_content_tag_enabled: Bool?
  let community_reviewed: Bool?
  var submit_text: String?
  var description_html: String?
  let spoilers_enabled: Bool?
  let allow_talks: Bool?
  let is_enrolled_in_new_modmail: Bool?
  let key_color: String?
  let can_assign_user_flair: Bool?
  let created: Double?
  let show_media_preview: Bool?
  var user_is_subscriber: Bool?
  let allow_videogifs: Bool?
  let should_archive_posts: Bool?
  let user_flair_type: String?
  let allow_polls: Bool?
  var public_description_html: String?
  let allow_videos: Bool?
  let banner_img: String?
  let user_flair_text: String?
  let banner_background_color: String?
  let show_media: Bool?
  let id: String
  let user_is_moderator: Bool?
  var description: String?
  let is_chat_post_feature_enabled: Bool?
  let submit_link_label: String?
  let user_flair_text_color: String?
  let restrict_commenting: Bool?
  let user_flair_css_class: String?
  let allow_images: Bool?
  let url: String
  let created_utc: Double?
  let user_is_contributor: Bool?
  var winstonFlairs: [Flair]?
  //  let comment_contribution_settings: CommentContributionSettings
  //  let header_size: [Int]?
  //  let user_flair_position: String?
  //  let all_original_content: Bool?
  //  let has_menu_widget: Bool?
  //  let wls: Int?
  //  let submission_type: String?
  //  let allowed_media_in_comments: [String]
  //  let collapse_deleted_comments: Bool?
  //  let emojis_custom_size: [Int]?
  //  let is_crosspostable_subreddit: Bool?
  //  let notification_level: String?
  //  let should_show_media_in_comments_setting: Bool?
  //  let can_assign_link_flair: Bool?
  //  let accounts_active_is_fuzzed: Bool?
  //  let allow_prediction_contributors: Bool?
  //  let submit_text_label: String?
  //  let link_flair_position: String?
  //  let user_sr_flair_enabled: Bool?
  //  let user_flair_enabled_in_sr: Bool?
  //  let allow_chat_post_creation: Bool?
  //  let allow_discovery: Bool?
  //  let accept_followers: Bool?
  //  let user_sr_theme_enabled: Bool?
  //  let link_flair_enabled: Bool?
  //  let disable_contributor_requests: Bool?
  //  let subreddit_type: String?
  //  let suggested_comment_sort: String?
  //  let over18: Bool?
  //  let header_title: String?
  //  let lang: String?
  //  let whitelist_status: String?
  //  let banner_size: [Int]?
  //  let mobile_banner_image: String?
  //  let allow_predictions_tournament: Bool?
  
  
  enum CodingKeys: String, CodingKey {
    case user_flair_background_color, submit_text_html, restrict_posting, user_is_banned, free_form_reports, wiki_enabled, user_is_muted, user_can_flair_in_sr, display_name, header_img, title, allow_galleries, icon_size, primary_color, active_user_count, icon_img, display_name_prefixed, accounts_active, public_traffic, subscribers, name, quarantine, hide_ads, prediction_leaderboard_entry_type, emojis_enabled, advertiser_category, public_description, comment_score_hide_mins, allow_predictions, user_has_favorited, user_flair_template_id, community_icon, banner_background_image, original_content_tag_enabled, community_reviewed, submit_text, description_html, spoilers_enabled, allow_talks, is_enrolled_in_new_modmail, key_color, can_assign_user_flair, created, show_media_preview, user_is_subscriber, allow_videogifs, should_archive_posts, user_flair_type, allow_polls, public_description_html, allow_videos, banner_img, user_flair_text, banner_background_color, show_media, id, user_is_moderator, description, is_chat_post_feature_enabled, submit_link_label, user_flair_text_color, restrict_commenting, user_flair_css_class, allow_images, url, created_utc, user_is_contributor, winstonFlairs
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    let id: String
    if let idValue = try? container.decode(String.self, forKey: .id) {
      id = idValue
    } else if let nameValue = try? container.decode(String.self, forKey: .name) {
      id = nameValue
    } else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath,
              debugDescription: "Unable to decode identification.")
      )
      
    }
    
    self.id = id
    
    self.user_flair_background_color = try container.decodeIfPresent(String.self, forKey: .user_flair_background_color)
    self.submit_text_html = try container.decodeIfPresent(String.self, forKey: .submit_text_html)
    self.restrict_posting = try container.decodeIfPresent(Bool.self, forKey: .restrict_posting)
    self.user_is_banned = try container.decodeIfPresent(Bool.self, forKey: .user_is_banned)
    self.free_form_reports = try container.decodeIfPresent(Bool.self, forKey: .free_form_reports)
    self.wiki_enabled = try container.decodeIfPresent(Bool.self, forKey: .wiki_enabled)
    self.user_is_muted = try container.decodeIfPresent(Bool.self, forKey: .user_is_muted)
    self.user_can_flair_in_sr = try container.decodeIfPresent(Bool.self, forKey: .user_can_flair_in_sr)
    self.display_name = try container.decodeIfPresent(String.self, forKey: .display_name)
    self.header_img = try container.decodeIfPresent(String.self, forKey: .header_img)
    self.title = try container.decodeIfPresent(String.self, forKey: .title)
    self.allow_galleries = try container.decodeIfPresent(Bool.self, forKey: .allow_galleries)
    self.icon_size = try container.decodeIfPresent([Int].self, forKey: .icon_size)
    self.primary_color = try container.decodeIfPresent(String.self, forKey: .primary_color)
    self.active_user_count = try container.decodeIfPresent(Int.self, forKey: .active_user_count)
    self.icon_img = try container.decodeIfPresent(String.self, forKey: .icon_img)
    self.display_name_prefixed = try container.decodeIfPresent(String.self, forKey: .display_name_prefixed)
    self.accounts_active = try container.decodeIfPresent(Int.self, forKey: .accounts_active)
    self.public_traffic = try container.decodeIfPresent(Bool.self, forKey: .public_traffic)
    self.subscribers = try container.decodeIfPresent(Int.self, forKey: .subscribers)
    self.name = try container.decode(String.self, forKey: .name)
    self.quarantine = try container.decodeIfPresent(Bool.self, forKey: .quarantine)
    self.hide_ads = try container.decodeIfPresent(Bool.self, forKey: .hide_ads)
    self.prediction_leaderboard_entry_type = try container.decodeIfPresent(String.self, forKey: .prediction_leaderboard_entry_type)
    self.emojis_enabled = try container.decodeIfPresent(Bool.self, forKey: .emojis_enabled)
    self.advertiser_category = try container.decodeIfPresent(String.self, forKey: .advertiser_category)
    self.public_description = try container.decode(String.self, forKey: .public_description)
    self.comment_score_hide_mins = try container.decodeIfPresent(Int.self, forKey: .comment_score_hide_mins)
    self.allow_predictions = try container.decodeIfPresent(Bool.self, forKey: .allow_predictions)
    self.user_has_favorited = try container.decodeIfPresent(Bool.self, forKey: .user_has_favorited)
    self.user_flair_template_id = try container.decodeIfPresent(String.self, forKey: .user_flair_template_id)
    self.community_icon = try container.decodeIfPresent(String.self, forKey: .community_icon)
    self.banner_background_image = try container.decodeIfPresent(String.self, forKey: .banner_background_image)
    self.original_content_tag_enabled = try container.decodeIfPresent(Bool.self, forKey: .original_content_tag_enabled)
    self.community_reviewed = try container.decodeIfPresent(Bool.self, forKey: .community_reviewed)
    self.submit_text = try container.decodeIfPresent(String.self, forKey: .submit_text)
    self.description_html = try container.decodeIfPresent(String.self, forKey: .description_html)
    self.spoilers_enabled = try container.decodeIfPresent(Bool.self, forKey: .spoilers_enabled)
    self.allow_talks = try container.decodeIfPresent(Bool.self, forKey: .allow_talks)
    self.is_enrolled_in_new_modmail = try container.decodeIfPresent(Bool.self, forKey: .is_enrolled_in_new_modmail)
    self.key_color = try container.decodeIfPresent(String.self, forKey: .key_color)
    self.can_assign_user_flair = try container.decodeIfPresent(Bool.self, forKey: .can_assign_user_flair)
    self.created = try container.decodeIfPresent(Double.self, forKey: .created)
    self.show_media_preview = try container.decodeIfPresent(Bool.self, forKey: .show_media_preview)
    self.user_is_subscriber = try container.decodeIfPresent(Bool.self, forKey: .user_is_subscriber)
    self.allow_videogifs = try container.decodeIfPresent(Bool.self, forKey: .allow_videogifs)
    self.should_archive_posts = try container.decodeIfPresent(Bool.self, forKey: .should_archive_posts)
    self.user_flair_type = try container.decodeIfPresent(String.self, forKey: .user_flair_type)
    self.allow_polls = try container.decodeIfPresent(Bool.self, forKey: .allow_polls)
    self.public_description_html = try container.decodeIfPresent(String.self, forKey: .public_description_html)
    self.allow_videos = try container.decodeIfPresent(Bool.self, forKey: .allow_videos)
    self.banner_img = try container.decodeIfPresent(String.self, forKey: .banner_img)
    self.user_flair_text = try container.decodeIfPresent(String.self, forKey: .user_flair_text)
    self.banner_background_color = try container.decodeIfPresent(String.self, forKey: .banner_background_color)
    self.show_media = try container.decodeIfPresent(Bool.self, forKey: .show_media)
    //  self.id = try container.decodeIfPresent(String.self, forKey: .id)
    self.user_is_moderator = try container.decodeIfPresent(Bool.self, forKey: .user_is_moderator)
    self.description = try container.decodeIfPresent(String.self, forKey: .description)
    self.is_chat_post_feature_enabled = try container.decodeIfPresent(Bool.self, forKey: .is_chat_post_feature_enabled)
    self.submit_link_label = try container.decodeIfPresent(String.self, forKey: .submit_link_label)
    self.user_flair_text_color = try container.decodeIfPresent(String.self, forKey: .user_flair_text_color)
    self.restrict_commenting = try container.decodeIfPresent(Bool.self, forKey: .restrict_commenting)
    self.user_flair_css_class = try container.decodeIfPresent(String.self, forKey: .user_flair_css_class)
    self.allow_images = try container.decodeIfPresent(Bool.self, forKey: .allow_images)
    self.url = try container.decode(String.self, forKey: .url)
    self.created_utc = try container.decodeIfPresent(Double.self, forKey: .created_utc)
    self.user_is_contributor = try container.decodeIfPresent(Bool.self, forKey: .user_is_contributor)
    self.winstonFlairs = try container.decodeIfPresent([Flair].self, forKey: .winstonFlairs)
  }
}

struct CommentContributionSettings: Codable, Hashable {
  let allowed_media_types: [String]?
}

struct SubListingSort: Codable, Identifiable {
  var icon: String
  var value: String
  var id: String {
    value
  }
}

enum SubListingSortOption: Codable, CaseIterable, Identifiable, Defaults.Serializable {
  var id: String {
    self.rawVal.id
  }
  
  case best
  case hot
  case new
  case top
  
  var rawVal: SubListingSort {
    switch self {
    case .best:
      return SubListingSort(icon: "trophy", value: "best")
    case .hot:
      return SubListingSort(icon: "flame", value: "hot")
    case .new:
      return SubListingSort(icon: "newspaper", value: "new")
    case .top:
      return SubListingSort(icon: "chart.line.uptrend.xyaxis", value: "top")
      
    }
  }
}
