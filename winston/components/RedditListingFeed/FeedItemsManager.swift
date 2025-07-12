//
//  FeedItemsManager.swift
//  winston
//
//  Created by Igor Marcossi on 26/01/24.
//

import SwiftUI
import Defaults
import Nuke

struct LoadingProgress {
  var currentCall: Int = 0
  var isActive: Bool = false
}

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
  private var subId: String
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
  
  var loadingProgress: LoadingProgress = LoadingProgress()
  
  init(sorting: S?, fetchFn: @escaping ItemsFetchFn, subId: String) {
    self.sorting = sorting
    self.fetchFn = fetchFn
    self.chunkSize = Defaults[.SubredditFeedDefSettings].chunkLoadSize
    self.subId = subId
  }
  
  func fetchCaller(loadingMore: Bool, force: Bool = false, hideRead: Bool = false, newEntities: [RedditEntityType]? = nil, newLoadedEntitiesIds: Set<String>? = nil, callCount: Int = 0) async {
    
    // Update progress at the start of each call
    await MainActor.run {
      loadingProgress.currentCall = callCount + 1
      loadingProgress.isActive = true
    }
    
    if !loadingMore, let currentTask, !currentTask.isCancelled {
      currentTask.cancel()
    }
    
    let lastElementId = (loadingMore || newEntities != nil) ? self.lastElementId : nil
    let searchQuery = selectedFilter?.type == .custom ? selectedFilter?.text : searchQuery.debounced.isEmpty ? nil : searchQuery.debounced
    let filter = selectedFilter?.type != .custom ? selectedFilter?.text : nil
    let noSearchQuery = searchQuery == nil || searchQuery == ""
    let sort = noSearchQuery ? sorting : (SubListingSortOption.new as? S)
    
    if let (fetchedEntities, after) = await fetchFn(lastElementId, sort, searchQuery, filter), let fetchedEntities {
      var newEntities = newEntities ?? []
      var newLoadedEntitiesIds = newLoadedEntitiesIds ?? []
      
      let seenPosts = hideRead ? SeenSubredditManager.shared.getSeenPosts(for: subId) : []
      
      fetchedEntities.forEach { ent in
        if newLoadedEntitiesIds.contains(ent.fullname) { return }
        
        var hidden = false
        if hideRead {
          switch ent {
          case .post(let post):
            if seenPosts.contains(post.id) {
              hidden = true
            }
          default:
            break
          }
        }
        
        if !hidden {
          newLoadedEntitiesIds.insert(ent.fullname)
          newEntities.append(ent)
        }
      }
      
      self.lastElementId = after
      
      if newEntities.count >= self.chunkSize || fetchedEntities.count < self.chunkSize {
        await MainActor.run { [newEntities, newLoadedEntitiesIds] in
          withAnimation {
            self.entities = loadingMore ? (entities + newEntities) : newEntities
            self.loadedEntitiesIds = loadingMore ? (loadedEntitiesIds.union(newLoadedEntitiesIds)) : newLoadedEntitiesIds
            self.displayMode = fetchedEntities.count < self.chunkSize ? .endOfFeed : .items
            
            // Reset progress when done
            self.loadingProgress.isActive = false
            self.loadingProgress.currentCall = 0
          }
        }
      } else {
        await fetchCaller(loadingMore: loadingMore, hideRead: hideRead, newEntities: newEntities, newLoadedEntitiesIds: newLoadedEntitiesIds, callCount: callCount + 1)
        return
      }
    } else {
      await MainActor.run {
        withAnimation {
          displayMode = .error
          loadingProgress.isActive = false
        }
      }
    }
    
    self.currentTask = nil
  }
  
  func elementAppeared(entity: RedditEntityType, index: Int, currentPostId: String?) async {
    await MainActor.run {
      // Move all property modifications here
      guard index >= 0 && index < entities.count else {
        print("Index out of bounds in elementAppeared: \(index)")
        return
      }
      
      guard entities[safe: index]?.id == entity.id else {
        print("Entity mismatch in elementAppeared")
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
      
      // Set lastAppearedId safely
      switch entity {
      case .post(let post):
        lastAppearedId = post.id + (post.winstonData?.uniqueId ?? "")
      default:
        lastAppearedId = entity.id
      }
      
      lastAppearedIndex = index
    }
    
    // Keep the rest of the logic outside if it doesn't need main thread
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
