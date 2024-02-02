//
//  fetchUsers.swift
//  winston
//
//  Created by Igor Marcossi on 04/07/23.
//

import Foundation
import Alamofire
import SwiftUI
import NukeUI
import Nuke
import Defaults

extension RedditAPI {
  func fetchUsers(_ ids: [String]) async -> MultipleUsersDictionary? {
    let payload = FetchUsersByIDPayload(ids: String(ids.joined(separator: ",")))
    switch await self.doRequest("\(RedditAPI.redditApiURLBase)/api/user_data_by_account_ids", method: .get, params: payload, paramsLocation: .queryString, decodable: MultipleUsersDictionary.self)  {
    case .success(let data):
      return data
    case .failure(let error):
      print(error)
      return nil
    }
  }
  
  func updateOverviewSubjectsWithAvatar(subjects: [Either<Post, Comment>], avatarSize: Double) async {
    var namesArr: [String] = []
    subjects.forEach { subject in
      switch subject {
      case .first(let post):
        if let data = post.data, let fullname = data.author_fullname {
          namesArr.append(fullname)
        }
      case .second(let comment):
        if let data = comment.data, let fullname = data.author_fullname {
          namesArr.append(fullname)
        }
      }
    }
    if let avatarsDict = await updateAvatarURL(names: namesArr, avatarSize: avatarSize) {
      subjects.forEach { subject in
        switch subject {
        case .first(let post):
          if let author = post.data?.author_fullname {
            DispatchQueue.main.async {
              post.winstonData?.avatarImageRequest = avatarsDict[author]
            }
          }
        case .second(let comment):
          if let authorFullname = comment.data?.author_fullname {
            DispatchQueue.main.async { [avatarsDict] in
              comment.winstonData?.avatarImageRequest = avatarsDict[authorFullname]
            }
          }
        }
      }
    }
  }
  
  func updateCommentsWithAvatar(comments: [Comment], avatarSize: Double, presentAvatarsDict: [String:ImageRequest]? = nil) async {
    let namesArr = presentAvatarsDict != nil ? [] : getNamesFromComments(comments)
    var avatarsDict: [String:ImageRequest] = presentAvatarsDict ?? [:]
    if avatarsDict.isEmpty, let newDict = await updateAvatarURL(names: namesArr, avatarSize: avatarSize) { avatarsDict = newDict }
    comments.forEach { comment in
      if let authorFullname = comment.data?.author_fullname {
        DispatchQueue.main.async { [avatarsDict] in
          comment.winstonData?.avatarImageRequest = avatarsDict[authorFullname]
        }
      }
      Task { [avatarsDict] in await self.updateCommentsWithAvatar(comments: comment.childrenWinston, avatarSize: avatarSize, presentAvatarsDict: avatarsDict) }
    }
  }
  
  func updatePostsWithAvatar(posts: [Post], avatarSize: Double) async {
    let namesArr = posts.compactMap { $0.data?.author_fullname }
    if let avatarsDict =  await updateAvatarURL(names: namesArr, avatarSize: avatarSize) {
      posts.forEach { post in
        if let author = post.data?.author_fullname {
          DispatchQueue.main.async { [avatarsDict] in
            post.winstonData?.avatarImageRequest = avatarsDict[author]
          }
        }
      }
    }
  }
  
  func updateAvatarURL(names: [String], avatarSize: Double) async -> [String:ImageRequest]? {
    let nonWinstonAppNames = names.filter { $0 != SAMPLE_USER_AVATAR }
    var returnDict: [String:ImageRequest] = [:]
    returnDict[SAMPLE_USER_AVATAR] = ImageRequest(stringLiteral: "https://winston.cafe/icons/iconExplode.png")
    
    if !nonWinstonAppNames.isEmpty, let data = await self.fetchUsers(nonWinstonAppNames) {
      //      let avatarSize = Defaults[]
      let newDict = data.compactMapValues { val in
        if let urlStr = val.profile_img, let url = URL(string: String(urlStr.split(separator: "?")[0])) {
          //          let userInfoKey = ImageRequest.UserInfoKey()
          //          ImageProcessing
//          let thumbOpt = ImageRequest.ThumbnailOptions(size: .init(width: avatarSize, height: avatarSize), unit: .points, contentMode: .aspectFill)
//          let req = ImageRequest(url: url, processors: [ImageProcessors.ScaleFixer()], priority: .veryHigh, userInfo: [.thumbnailKey: thumbOpt])
          let req = ImageRequest(url: url, processors: [ImageProcessors.Resize(width: avatarSize), ImageProcessors.ScaleFixer()], priority: .veryHigh)
          return req
        }
        return nil
      }

      return newDict.merging(returnDict) { x, _ in x }
    }
    return returnDict
  }
  
  struct FetchUsersByIDPayload: Codable {
    let ids: String
    var raw_json = 1
  }
  
  typealias MultipleUsersDictionary = [String: MultipleUsersUser]
  
  struct MultipleUsersUser: Codable {
    let name: String?
    let created_utc: Double?
    let link_karma: Int?
    let comment_karma: Int?
    let profile_img: String?
    let profile_color: String?
    let profile_over_18: Bool?
  }
}

func getNamesFromComments(_ comments: [Comment]) -> [String] {
  var namesArr: [String] = []
  comments.forEach { comment in
    if let fullname = comment.data?.author_fullname {
      namesArr.append(fullname)
    }
    namesArr += getNamesFromComments(comment.childrenWinston)
  }
  return namesArr
}
