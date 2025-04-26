//
//  SubItem.swift
//  winston
//
//  Created by Igor Marcossi on 05/08/23.
//

import SwiftUI
import Defaults

struct SubItemButton: View, Equatable {
  static func == (lhs: SubItemButton, rhs: SubItemButton) -> Bool {
    lhs.data == rhs.data
  }
  
  var data: SubredditData
  var action: () -> ()
  var body: some View {
    Button(action: action) {
        HStack {
          Text(data.display_name ?? "")
          SubredditIcon(subredditIconKit: data.subredditIconKit)
        }
      }
  }
}

struct SubItem: View, Equatable {
  static func == (lhs: SubItem, rhs: SubItem) -> Bool {
    lhs.sub == rhs.sub && lhs.isActive == rhs.isActive && lhs.showSubs == rhs.showSubs
  }
  
  var isActive: Bool
  var sub: Subreddit
  var cachedSub: CachedSub? = nil
  var action: (Subreddit) -> ()
  @Binding var localFavState: [String]
  var showSubs: Bool = false
  
  @Default(.localFavorites) private var localFavorites
  
  func localFavoriteToggle() {
      guard let name = cachedSub?.name ?? sub.data?.name else { return }
      
      if localFavorites.contains(name) {
        localFavorites = localFavorites.filter { $0 != name }
      } else {
        localFavorites.append(name)
      }
      
      DispatchQueue.main.async {
        withAnimation {
          localFavState = localFavorites
        }
      }
  }
  
  func getFormattedSubscribers(_ data: SubredditData) -> String{
    guard let subs = data.subscribers else { return "" }
    
    if subs < 1000 {
      return "\(subs)"
    } else if subs < 1000000 {
      return String(subs / 1000) + "K"
    } else {
      let subStr = String(format: "%.1f",  Double(subs) / 1000000.0)
      return (subStr.hasSuffix(".0") ? String(subStr.dropLast(2)) : subStr) + "M"
    }
    
  }
  
  var body: some View {
    if let data = sub.data {
//      let favorite = cachedSub.user_has_favorited
        let localFav = localFavorites.contains(sub.id)
//      let isActive = selectedSub == .reddit(.subFeed(sub))
      WListButton(showArrow: !IPAD, active: isActive) {
        action(sub)
      } label: {
        HStack {
          Label {
            Text(data.display_name ?? "")
              .foregroundStyle(isActive ? .white : .primary)
          } icon: {
            SubredditIcon(subredditIconKit: data.subredditIconKit)
          }
          
          if showSubs {
            Text(getFormattedSubscribers(data))
              .fontSize(15, .bold)
              .foregroundColor(Color(UIColor(hex: "444444")))
          }
          
          Spacer()
          
          Image(systemName: "star.fill")
            .foregroundColor(localFav ? Color.accentColor : .gray.opacity(0.3))
            .highPriorityGesture( TapGesture().onEnded(localFavoriteToggle) )
        }
      }
      
    } else {
      Text("Error")
    }
  }
}
