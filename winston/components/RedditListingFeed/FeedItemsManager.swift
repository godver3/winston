//
//  FeedItemsManager.swift
//  winston
//
//  Created by Igor Marcossi on 26/01/24.
//

import SwiftUI
import Defaults
import Nuke

@Observable
class FeedItemsManager<S> {
  typealias ItemsFetchFn = (_ lastElementId: String?, _ sorting: S?, _ searchQuery: String?, _ flair: String?) async -> (entities: [RedditEntityType]?, after: String?)?
  
  enum DisplayMode: String { case loading, empty, items, endOfFeed, error }
  
  private var currentTask: Task<(), Never>? = nil
  var displayMode: DisplayMode = .loading
  var loadingPinned = false
  var pinnedPosts: [Post] = []
  var entities: [RedditEntityType] = []
  var loadedEntitiesIds: Set<String> = []
  var lastElementId: String? = nil
  var sorting: S? {
      willSet { withAnimation { displayMode = .loading } }
  }
  var searchQuery = Debouncer("")
  var selectedFilter: ShallowCachedFilter? {
      willSet { withAnimation { displayMode = .loading } }
  }
  var chunkSize: Int
  private var onScreenEntities: [(entity: RedditEntityType, index: Int)] = []
  private var fetchFn: ItemsFetchFn
  private let prefetchRange = 2

  private var lastNoSearchEntitites: [RedditEntityType] = []
  private var lastNoSearchLastElementId: String? = nil
  private var lastNoSearchLoadedEntitiesIds: Set<String> = []
  private var lastNoSearchDisplayMode: DisplayMode = .loading
  private var lastSort: SubListingSortOption?
  
  var lastAppearedIndex = 0
  var lastAppearedId = ""
  
  private var scrollingDown = true
  private var scrolling = false
  
  var scrollProxy: ScrollViewProxy? = nil
  
  private var previousId: String? = nil

    init(sorting: S?, fetchFn: @escaping ItemsFetchFn) {
        self.sorting = sorting
        self.fetchFn = fetchFn
        self.chunkSize = Defaults[.SubredditFeedDefSettings].chunkLoadSize
    }
  
  func fetchCaller(loadingMore: Bool, force: Bool = false) async {
        if !loadingMore, let currentTask, !currentTask.isCancelled {
            currentTask.cancel()
        }
      
        let lastElementId = loadingMore ? self.lastElementId : nil
        let searchQuery = selectedFilter?.type == .custom ? selectedFilter?.text : searchQuery.debounced.isEmpty ? nil : searchQuery.debounced
        let filter = selectedFilter?.type != .custom ? selectedFilter?.text : nil
        let noSearchQuery = searchQuery == nil || searchQuery == ""
        let sort = noSearchQuery ? sorting : (SubListingSortOption.new as? S)
        
        if noSearchQuery && self.lastNoSearchEntitites.count > 0 && !force && !loadingMore && (sort as? SubListingSortOption) == self.lastSort {
            await MainActor.run {
              withAnimation {
                self.displayMode = self.lastNoSearchDisplayMode
                self.entities = self.lastNoSearchEntitites
                self.lastElementId = self.lastNoSearchLastElementId
                self.loadedEntitiesIds = self.lastNoSearchLoadedEntitiesIds
              }
            }
        } else if let (fetchedEntities, after) = await fetchFn(lastElementId, sort, searchQuery, filter), let fetchedEntities {
            if !loadingMore {
              var newLoadedEntitiesIds = Set<String>()
              fetchedEntities.forEach { ent in
                newLoadedEntitiesIds.insert(ent.fullname)
              }
            
              DispatchQueue.main.async {
                if self.entities.count == fetchedEntities.count && self.entities.first?.id == fetchedEntities.first?.id {
                  self.displayMode = fetchedEntities.count == 0 ? .empty : fetchedEntities.count < self.chunkSize ? .endOfFeed : .items
                  self.entities = fetchedEntities
                  self.lastElementId = after
                  self.loadedEntitiesIds = newLoadedEntitiesIds
                } else {
                  withAnimation {
                    self.displayMode = fetchedEntities.count == 0 ? .empty : fetchedEntities.count < self.chunkSize ? .endOfFeed : .items
                    self.entities = fetchedEntities
                    self.lastElementId = after
                    self.loadedEntitiesIds = newLoadedEntitiesIds
                  }
                }
              }
              
              if (noSearchQuery) {
                self.lastNoSearchDisplayMode = self.displayMode
                self.lastNoSearchEntitites = self.entities
                self.lastNoSearchLastElementId = self.lastElementId
                self.lastNoSearchLoadedEntitiesIds = self.loadedEntitiesIds
                self.lastSort = sort as? SubListingSortOption
              }

              return
            }
            
            var newEntities = entities
          
            fetchedEntities.forEach { ent in
              if loadedEntitiesIds.contains(ent.fullname) { return }
              loadedEntitiesIds.insert(ent.fullname)
              newEntities.append(ent)
            }

//          print("[LIST-LOAD] Adding \(newEntities.count) entities, first = \(newEntities.first?.id ?? "")")
          await MainActor.run { [newEntities ] in
            self.entities = newEntities
            self.displayMode = fetchedEntities.count < self.chunkSize ? .endOfFeed : .items
          }
            
          self.lastElementId = after
        } else {
            withAnimation { displayMode = .error }
        }
      
      self.currentTask = nil
    }
    
    func elementAppeared(entity: RedditEntityType, index: Int, currentPostId: String?) async {
//      print("[LIST-APPEARED] idx: \(index) id: \(entity.id)")
      
      // Add bounds checking
      guard index >= 0 && index < entities.count else {
          print("Index out of bounds in elementAppeared: \(index)")
          return
      }
      
      // Ensure entity matches the one at the index
      guard entities[safe: index]?.id == entity.id else {
          print("Entity mismatch in elementAppeared - expected: \(entities[safe: index]?.id ?? "nil"), got: \(entity.id)")
          return
      }
      
      if currentPostId != nil, !scrolling, !lastAppearedId.isEmpty, scrollingDown && (index - lastAppearedIndex) > 3, let scrollProxy {
        scrolling = true
        
        print("[LIST-WARN] Skipped \(abs(lastAppearedIndex - index)) posts. Scrolling back to \(lastAppearedId)")
        scrollProxy.scrollTo(lastAppearedId, anchor: .center)
        lastAppearedId = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          self.scrolling = false
        }
        
        return
      }
      
      scrollingDown = index > lastAppearedIndex
            
      switch entity {
        case .post(let post):
          lastAppearedId = post.id + (post.winstonData?.uniqueId ?? "")
          break
        default:
          lastAppearedId = entity.id
          break
      }

      lastAppearedIndex = index
        
      if displayMode != .endOfFeed, entities.count > 0, index >= entities.count - 2, currentTask == nil {
          self.currentTask = Task { await fetchCaller(loadingMore: true) }
      }
      
      // Safer prefetching with bounds checking
      let start = max(0, index - prefetchRange)
      let end = min(entities.count, index + prefetchRange + 1)
      
      guard start < end else { return }
      
      let toPrefetch = Array(entities[start..<end])
      
      do {
          let reqs = getImgReqsFrom(toPrefetch)
          Post.prefetcher.startPrefetching(with: reqs)
      } catch {
          print("Error in prefetching: \(error)")
      }
    }
    
    func elementDisappeared(entity: RedditEntityType, index: Int) async {
        do {
            let reqs = getImgReqsFrom([entity])
            Post.prefetcher.stopPrefetching(with: reqs)
        } catch {
            print("Error in elementDisappeared prefetching: \(error)")
        }
    }
    
    private func getImgReqsFrom(_ entities: [RedditEntityType]) -> [ImageRequest] {
        // Create a copy to avoid concurrent modification issues
        let entitiesCopy = entities
        var imageRequests: [ImageRequest] = []
        
        for entity in entitiesCopy {
            do {
                switch entity {
                case .post(let post):
                    // Handle avatar image request
                    if let avatarImgReq = post.winstonData?.avatarImageRequest {
                        imageRequests.append(avatarImgReq)
                    }
                    
                    // Handle extracted media with individual error handling
                    guard let extractedMedia = post.winstonData?.extractedMedia else { continue }
                    
                    switch extractedMedia {
                    case .comment(_):
                        break
                    case .imgs(let imgsExtracted):
                        for imgExtracted in imgsExtracted {
                            do {
                                let request = imgExtracted.request
                                imageRequests.append(request)
                            } catch {
                                print("Failed to create image request for imgExtracted: \(error)")
                                continue
                            }
                        }
                    case .link(let link):
                        if let imgReq = link.imageReq {
                            imageRequests.append(imgReq)
                        }
                    case .video(_):
                        break
                    case .yt(let video):
                        do {
                            let thumbnailReq = video.thumbnailRequest
                            imageRequests.append(thumbnailReq)
                        } catch {
                            print("Failed to create YouTube thumbnail request: \(error)")
                        }
                    case .streamable(_), .repost(_), .post(_), .subreddit(_), .user(_):
                        break
                    }
                default:
                    break
                }
            } catch {
                print("Error processing entity \(entity.id): \(error)")
                continue
            }
        }
        
        return imageRequests
    }
}

// Extension for safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
