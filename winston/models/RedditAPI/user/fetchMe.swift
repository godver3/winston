//
//  fetchMe.swift
//  winston
//
//  Created by Igor Marcossi on 01/07/23.
//

import Foundation
import Alamofire

extension RedditAPI {
  func fetchMe(force: Bool = false, altCredential: RedditCredential? = nil, saveToken: Bool = true) async -> UserData? {
    if !force, let me = me {
        await MainActor.run {
            RedditAPI.shared.me = me
        }
    } else {
      switch await self.doRequest("\(RedditAPI.redditApiURLBase)/api/v1/me", method: .get, decodable: UserData.self, altCredential: altCredential, saveToken: saveToken)  {
      case .success(let data):
        await MainActor.run {
          RedditAPI.shared.me = User(data: data)
        }
        return data
      case .failure(let error):
        print(error)
        await MainActor.run {
          RedditAPI.shared.me = nil
        }
        return nil
      }
    }
    return nil
  }
}

