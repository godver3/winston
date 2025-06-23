//
//  Posts.swift
//  winston
//
//  Created by Igor Marcossi on 24/06/23.
//

import SwiftUI
import Defaults
import Combine
import SwiftDate
import Shiny

let alphabetLetters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { String($0) }

struct Subreddits: View, Equatable {
  static func == (lhs: Subreddits, rhs: Subreddits) -> Bool {
    return lhs.loaded == rhs.loaded && lhs.currentCredentialID == rhs.currentCredentialID
  }
//  @State
  @Binding var firstDestination: Router.NavDest?
  var loaded: Bool
  var currentCredentialID: UUID
  
  @Default(.localFavorites) private var localFavorites
  @State private var localFavState: [String] = []
  
  init(firstDestination: Binding<Router.NavDest?>, loaded: Bool, currentCredentialID: UUID) {
    self.currentCredentialID = currentCredentialID
    self._firstDestination = firstDestination
    self.loaded = loaded
    self._subreddits = FetchRequest<CachedSub>(sortDescriptors: [NSSortDescriptor(key: "display_name", ascending: true)], predicate: NSPredicate(format: "winstonCredentialID == %@", currentCredentialID as CVarArg), animation: .default)
    self._multis = FetchRequest<CachedMulti>(sortDescriptors: [NSSortDescriptor(key: "display_name", ascending: true)], predicate: NSPredicate(format: "winstonCredentialID == %@", currentCredentialID as CVarArg), animation: .default)
    
    _localFavState = State(initialValue: localFavorites)
  }
  
  @FetchRequest private var subreddits: FetchedResults<CachedSub>
  @FetchRequest private var multis: FetchedResults<CachedMulti>
  
  @State private var searchText = Debouncer("", delay: 0.25)
  @State private var matchedSubs: [Subreddit] = []
  
  @Default(.AppearanceDefSettings) private var appearanceDefSettings
  @Environment(\.managedObjectContext) private var context
  @Environment(\.useTheme) private var selectedTheme
  
  var sections: [String:[CachedSub]] {
    return Dictionary(grouping: subreddits.filter({ $0.user_is_subscriber })) { sub in
      return String((sub.display_name ?? "a").first!.uppercased())
    }
  }
  
  func selectSub(_ sub: Subreddit) { firstDestination = .reddit(.subFeed(sub)) }
  
  var body: some View {
    ScrollViewReader { proxy in
      List(selection: $firstDestination) {
        if searchText.debounced == "" {
          VStack(spacing: 12) {
            HStack(spacing: 12) {
              ListBigBtn(icon: "chart.line.uptrend.xyaxis.circle.fill", iconColor: .blue, label: "Popular") {
                firstDestination = .reddit(.subFeed(Subreddit(id: "popular")))
              }
              
              ListBigBtn(icon: "bookmark.circle.fill", iconColor: .green, label: "Saved") {
                firstDestination = .reddit(.subFeed(Subreddit(id: savedKeyword)))
              }
            }
            HStack(spacing: 12) {
              ListBigBtn(icon: "signpost.right.and.left.circle.fill", iconColor: .orange, label: "All") {
                firstDestination = .reddit(.subFeed(Subreddit(id: "all")))
              }
              
              ListBigBtn(icon: "house.circle.fill", iconColor: .red, label: "Home") {
                firstDestination = .reddit(.subFeed(Subreddit(id: "home")))
              }
            }
          }
          .environment(\.isInSidebar, false)
          .frame(maxWidth: .infinity)
          .id("bigButtons")
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
          
          //          Section{
          //            UpsellCard(upsellName: "themesUpsell_01", {
          //                Text("Tired of Winstons current look? Try the theme editor in settings now!")
          //                .winstonShiny()
          //              .fontWeight(.semibold)
          //              .font(.system(size: 15))
          //            })
          //            .padding()
          //          }
          //          .listRowSeparator(.hidden)
          ////            .listRowBackground(Color.clear)
          //          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
          
          PostsInBoxView()
            .scrollIndicators(.hidden)
          //            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
          
          if multis.count > 0 {
            Section("Multis") {
              ScrollView(.horizontal) {
                HStack(spacing: 16) {
                  ForEach(multis) { multi in
                    MultiLink(multi: Multi(data: MultiData(entity: multi)))
                  }
                }
                .padding(.horizontal, 16)
              }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
          }
          
        }
        
        Group {
                    
          if searchText.debounced != "" {
            let foundSubs = Array(subreddits.filter {  ($0.user_is_subscriber || localFavorites.contains($0.name ?? "")) && ($0.display_name ?? "").lowercased().starts(with: searchText.debounced.lowercased()) })
            
            if foundSubs.count > 0 {
              Section("My subs") {
                ForEach(foundSubs, id: \.self.uuid) { cachedSub in
                  let sub = Subreddit(data: SubredditData(entity: cachedSub))
                  SubItem(isActive: Router.NavDest.reddit(.subFeed(sub)) == firstDestination, sub: sub, cachedSub: cachedSub, action: selectSub, localFavState: $localFavState, showSubs: true)
                }
              }
            }
            
            
            let filteredMatches = matchedSubs.filter { match in !foundSubs.contains(where: { cached in cached.name == match.data?.name })}
            Section("All subs") {
              ForEach(filteredMatches, id: \.self.id) { sub in
                SubItem(isActive: Router.NavDest.reddit(.subFeed(sub)) == firstDestination, sub: sub, action: selectSub, localFavState: $localFavState, showSubs: true)
              }
            }
            
          } else {
            if localFavState.count > 0 {
              Section("Favorites") {
                let favs = localFavState.map { name in subreddits.first(where: { sub in sub.name == name }) ?? nil }.filter { $0 != nil }.map { $0! }
                
                ForEach(favs, id: \.self) { cachedSub in
                  let sub = Subreddit(data: SubredditData(entity: cachedSub))
                  SubItem(isActive: Router.NavDest.reddit(.subFeed(sub)) == firstDestination, sub: sub, cachedSub: cachedSub, action: selectSub, localFavState: $localFavState)
                    .id("\(cachedSub.uuid ?? "")-fav")
                    .onAppear{
                      UIApplication.shared.shortcutItems?.append(UIApplicationShortcutItem(type: "subFav", localizedTitle: cachedSub.display_name ?? "Test", localizedSubtitle: "", icon: UIApplicationShortcutIcon(type: .love), userInfo: ["name" : "sub" as NSSecureCoding]))
                    }
                }
                .onMove { source, destination in
                  localFavState.move(fromOffsets: source, toOffset: destination)
                  localFavorites.move(fromOffsets: source, toOffset: destination)
                }
                .onDelete { offsets in
                  localFavState.remove(atOffsets: offsets)
                  localFavorites.remove(atOffsets: offsets)
                }
              }
            }
            
            if appearanceDefSettings.disableAlphabetLettersSectionsInSubsList {
              
              Section("Subs") {
                let subs = Array(subreddits.filter({ $0.user_is_subscriber }).sorted(by: { x, y in (x.display_name?.lowercased() ?? "a") < (y.display_name?.lowercased() ?? "a") }).enumerated())
                ForEach(subs, id: \.self.element) { i, cachedSub in
                  let sub = Subreddit(data: SubredditData(entity: cachedSub))
                  SubItem(isActive: Router.NavDest.reddit(.subFeed(sub)) == firstDestination, sub: sub, cachedSub: cachedSub, action: selectSub, localFavState: $localFavState)
                }
              }
              
            } else {
              
              ForEach(sections.keys.sorted(), id: \.self) { letter in
                Section(header: Text(letter)) {
                  if let arr = sections[letter] {
                    let subs = Array(arr.sorted(by: { x, y in
                      (x.display_name?.lowercased() ?? "a") < (y.display_name?.lowercased() ?? "a")
                    }).enumerated())
                    ForEach(subs, id: \.self.element.uuid) { i, cachedSub in
                      let sub = Subreddit(data: SubredditData(entity: cachedSub))
                      SubItem(isActive: Router.NavDest.reddit(.subFeed(sub)) == firstDestination, sub: sub, cachedSub: cachedSub, action: selectSub, localFavState: $localFavState)
                    }
                    .onDelete(perform: { i in
                      deleteFromList(at: i, letter: letter)
                    })
                  }
                }
              }
            }
            
          }
        }
        .themedListSection()
      }
      .environment(\.isInSidebar, true)
      .themedListBG(selectedTheme.lists.bg)
      .scrollIndicators(.hidden)
      .listStyle(.sidebar)
      .scrollDismissesKeyboard(.immediately)
      .loader(!loaded && subreddits.count == 0)
      .searchable(text: $searchText.value, prompt: "Search my subreddits")
      .onChange(of: searchText.debounced) { _, newValue in
        Task {
          let matches = await RedditAPI.shared.searchSubreddits(newValue)?.map({ Subreddit(data: $0) })
          
          DispatchQueue.main.async { [self, matches] in
            withAnimation {
              self.matchedSubs = matches != nil ? matches! : []
            }
          }
        }
      }
      .onChange(of: localFavorites) {
        localFavState = localFavorites
      }
//      .toolbar {
//        ToolbarItem(placement: .navigationBarTrailing) {
//          EditButton()
//        }
//      }
      .overlay(
        AlphabetJumper(letters: sections.keys.sorted(), searchText: $searchText, proxy: proxy)
          , alignment: .trailing
      )
      .refreshable {
        Task(priority: .background) {
          await updatePostsInBox(RedditAPI.shared, force: true)
        }
        Task(priority: .background) {
          _ = await RedditAPI.shared.fetchMyMultis()
        }
        _ = await RedditAPI.shared.fetchSubsAndSyncCoreData()
      }
      .navigationTitle("Subs")
    }
  }
  
  func deleteFromList(at offsets: IndexSet, letter: String) {
    for i in offsets {
      if let sub = sections[letter]?.sorted(by: { x, y in
        (x.display_name?.lowercased() ?? "a") < (y.display_name?.lowercased() ?? "a")
      })[i] {
        Task(priority: .background) {
          Subreddit(data: SubredditData(entity: sub)).subscribeToggle(optimistic: true)
        }
      }
    }
  }
}

//struct Posts_Previews: PreviewProvider {
//  static var previews: some View {
//    Posts()
//  }
//}
