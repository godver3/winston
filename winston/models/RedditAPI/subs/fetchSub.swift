//
//  fetchSub.swift
//  winston
//
//  Created by Igor Marcossi on 30/06/23.
//

import Foundation
import Alamofire
import Defaults
import SwiftUI
import CoreData

extension RedditAPI {
  func fetchSub(_ name: String) async -> ListingChild<SubredditData>? {
    switch await self.doRequest("\(RedditAPI.redditApiURLBase)\(name.hasPrefix("/r/") ? name : "/r/\(name)/")about.json?raw_json=1", method: .get, decodable: ListingChild<SubredditData>.self)  {
    case .success(let data):
      Task { await updateSubInCoreData(with: data) }
      return data
    case .failure(let error):
      print(error)
      return nil
    }
  }
    
    func updateSubInCoreData(with sub: ListingChild<SubredditData>) async {
      guard let credentialID = Defaults[.GeneralDefSettings].redditCredentialSelectedID else { return }
      let context = PersistenceController.shared.container.newBackgroundContext()
      
      await context.perform(schedule: .enqueued) {
        let fetchRequest = NSFetchRequest<CachedSub>(entityName: "CachedSub")
        fetchRequest.predicate = NSPredicate(format: "winstonCredentialID == %@", credentialID as CVarArg)
        do {
          let results = try context.fetch(fetchRequest)
          
          // Insert or update CachedSub with the fetched sub data
          
          if let data = sub.data {
             if let existingSub = results.first(where: { $0.uuid == data.name }) {
              // Update existing CachedSub
              existingSub.update(data: data, credentialID: credentialID)
            } else {
              // Create new CachedSub
              let newSub = CachedSub(context: context)
              newSub.update(data: data, credentialID: credentialID)
            }
          }
          
          // Save changes
          try withAnimation {
            try context.save()
          }
        } catch {
          print("Failed to fetch or save CachedSub: \(error)")
        }
      }
    }
}
