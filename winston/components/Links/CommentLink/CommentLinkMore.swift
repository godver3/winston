//
//  CommentLinkMore.swift
//  winston
//
//  Created by Igor Marcossi on 17/07/23.
//

import SwiftUI
import Defaults

// Shared state manager for auto-load queue
class CommentAutoLoadManager: ObservableObject {
    static let shared = CommentAutoLoadManager()
    
    @Published var currentAutoLoadingCommentId: String? = nil
    private var currentAutoLoadingIndex: Int? = nil // Track the index of currently loading comment
    private var queuedComments: [(id: String, index: Int)] = []
    private var visibleComments: Set<String> = [] // Track visible CommentLinkMore items
    private var pendingComments: Set<String> = [] // Track pending CommentLinkMore items
    private var currentTopCommentIdx: Int = 0
    
    private init() {}
    
    func canStartAutoLoad(for commentId: String, at index: Int) -> Bool {
        return currentAutoLoadingCommentId == nil
    }
    
    func requestAutoLoadSlot(for commentId: String, at index: Int) {
        // Add to visible comments when requesting slot
        visibleComments.insert(commentId)
        
        // Add to queue if not already there
        if !queuedComments.contains(where: { $0.id == commentId }) {
            queuedComments.append((id: commentId, index: index))
            // Sort by index to prioritize comments higher up
            queuedComments.sort { $0.index < $1.index }
        }
        
        // Check if we should interrupt the current loading comment with a higher priority one
        // But only if both comments are in the valid range (>= topCommentIdx)
        if let currentLoadingId = currentAutoLoadingCommentId,
           let currentLoadingIdx = currentAutoLoadingIndex,
           index < currentLoadingIdx {
            // New comment has higher priority, stop current and start new one immediately
            print("[AUTO-LOAD \(Date().timeIntervalSinceReferenceDate)] Interrupting comment \(currentLoadingId) at index \(currentLoadingIdx) for higher priority comment \(commentId) at index \(index)")
            stopAutoLoad(for: currentLoadingId)
            startAutoLoad(for: commentId, at: index)
        } else {
            // Try to start the next comment if nothing is currently loading
            processQueue()
        }
    }
    
    // New method for comments that appear but don't have an index yet
    func markCommentVisiblePending(_ commentId: String) {
        pendingComments.insert(commentId)
    }
    
  func processIndexMapUpdate(_ commentIndexMap: [String: Int]) {
      let pendingToProcess = Array(pendingComments)
      
      for commentId in pendingToProcess {
          if let index = commentIndexMap[commentId] {
              // Found index for pending comment, process it
              pendingComments.remove(commentId)
              
              // Only process if it's >= currentTopCommentIdx
              if index >= currentTopCommentIdx {
                  // Add to visible comments and queue
                  visibleComments.insert(commentId)
                  
                  // Add to queue if not already there
                  if !queuedComments.contains(where: { $0.id == commentId }) {
                      queuedComments.append((id: commentId, index: index))
                  }
              }
          }
      }
      
      // IMPORTANT: Re-sort the entire queue after adding new comments
      queuedComments.sort { $0.index < $1.index }
      
      // Only process queue if nothing is currently loading
      if currentAutoLoadingCommentId == nil {
          processQueue()
      }
  }

    
  private func processQueue() {
    guard currentAutoLoadingCommentId == nil && !queuedComments.isEmpty else {
        return
    }
    
    // Get the comment with the lowest index (highest priority)
    let nextComment = queuedComments.removeFirst()
    startAutoLoad(for: nextComment.id, at: nextComment.index)
  }
  
  func startAutoLoad(for commentId: String, at index: Int) {
      currentAutoLoadingCommentId = commentId
      currentAutoLoadingIndex = index
      // Force UI update
      DispatchQueue.main.async {
          self.objectWillChange.send()
      }
  }
  
  func startAutoLoad(for commentId: String) {
      // Legacy method - try to find index from queue
      if let queueItem = queuedComments.first(where: { $0.id == commentId }) {
          startAutoLoad(for: commentId, at: queueItem.index)
      } else {
          currentAutoLoadingCommentId = commentId
          currentAutoLoadingIndex = nil
          DispatchQueue.main.async {
              self.objectWillChange.send()
          }
      }
  }
  
  func stopAutoLoad(for commentId: String) {
      if currentAutoLoadingCommentId == commentId {
          currentAutoLoadingCommentId = nil
          currentAutoLoadingIndex = nil
          // Process next in queue immediately
          DispatchQueue.main.async {
              self.processQueue()
          }
      }
  }
  
  func isCurrentlyAutoLoading(_ commentId: String) -> Bool {
      return currentAutoLoadingCommentId == commentId
  }
  
  func removeFromQueue(_ commentId: String) {
      queuedComments.removeAll { $0.id == commentId }
  }
  
  func markCommentInvisible(_ commentId: String) {
      visibleComments.remove(commentId)
      pendingComments.remove(commentId)
  }
  
  func markCommentCancelled(_ commentId: String) {
      // Remove from all tracking when manually cancelled
      print("[AUTO-LOAD \(Date().timeIntervalSinceReferenceDate)] Comment \(commentId) CANCELLED - removing from all tracking")
      visibleComments.remove(commentId)
      pendingComments.remove(commentId)
      removeFromQueue(commentId)
  }
  
  func isCommentVisible(_ commentId: String) -> Bool {
      return visibleComments.contains(commentId) || pendingComments.contains(commentId)
  }
    
    // New method to handle topCommentIdx changes
  func handleTopCommentIndexChange(_ topCommentIdx: Int, commentIndexMap: [String: Int]) {
      currentTopCommentIdx = topCommentIdx
      
      // Remove comments that are above the visible area from the queue
      let commentsToRemove = queuedComments.filter { queueItem in
          queueItem.index < topCommentIdx
      }
      
      for comment in commentsToRemove {
          removeFromQueue(comment.id)
          // If this was the currently loading comment, stop it
          if currentAutoLoadingCommentId == comment.id {
              stopAutoLoad(for: comment.id)
          }
      }
      
      // Re-add visible comments that are now back in the visible range and not already in queue
      for commentId in visibleComments {
          if let commentIndex = commentIndexMap[commentId],
             commentIndex >= topCommentIdx,
             !queuedComments.contains(where: { $0.id == commentId }) {
              queuedComments.append((id: commentId, index: commentIndex))
          }
      }
      
      // IMPORTANT: Re-sort the entire queue after modifications
      queuedComments.sort { $0.index < $1.index }
      
      // Only process queue if nothing is currently loading
      if currentAutoLoadingCommentId == nil {
          processQueue()
      }
  }
}

struct CommentLinkMore: View {
  var arrowKinds: [ArrowKind]
  var comment: Comment
  weak var post: Post?
  var postFullname: String?
  var parentElement: CommentParentElement?
  var indentLines: Int?
  var topCommentIdx: Int
  var commentIndexMap: [String: Int]
  var newCommentsLoaded: (() -> Void)?
  var index: Int = 0
  
  @State var loadMoreLoading = false
  @State var autoLoadProgress: Double = 0.0
  @State var autoLoadTimer: Timer? = nil
  @State var resetProgressTimer: Timer? = nil
  @State var hasRequestedAutoLoad = false
  
  @Environment(\.useTheme) private var selectedTheme
  @StateObject private var autoLoadManager = CommentAutoLoadManager.shared
  
  private let timerInterval: TimeInterval = 0.1
  
  private func getAutoLoadDuration() -> TimeInterval {
    return NetworkMonitor.shared.connectedToWifi ? 1.5 : 3
  }
    
  func handleTap() {
    // Cancel auto-load timer when manually tapped
    cancelAutoLoadTimer()
    
    if let postFullname = postFullname, let parentElement = parentElement {
      withAnimation(spring) {
        loadMoreLoading = true
      }
      Task(priority: .background) {
        await comment.loadChildren(parent: parentElement, postFullname: postFullname, avatarSize: selectedTheme.comments.theme.badge.avatar.size, post: post, index: index)
        
          await MainActor.run {
            doThisAfter(0.5) {
              withAnimation(spring) {
                loadMoreLoading = false
              }
            }
          }
          
          newCommentsLoaded?()
      }
    }
  }
  
  private func requestAutoLoadSlot() {
    guard !hasRequestedAutoLoad else { return }
    
    if let currentIndex = commentIndexMap[comment.id] {
      // We have an index, proceed normally
      print("[AUTO-LOAD \(Date().timeIntervalSinceReferenceDate)] Comment \(comment.id) requesting slot at index \(currentIndex)")
      hasRequestedAutoLoad = true
      autoLoadManager.requestAutoLoadSlot(for: comment.id, at: currentIndex)
    } else {
      // No index yet, mark as pending
      print("[AUTO-LOAD \(Date().timeIntervalSinceReferenceDate)] Comment \(comment.id) marked as pending (no index yet)")
      autoLoadManager.markCommentVisiblePending(comment.id)
      // Don't set hasRequestedAutoLoad = true here, so we can try again when index map updates
    }
  }
  
  // Add this new method to handle when index becomes available
  private func handleIndexMapUpdate() {
    // If we haven't requested auto load yet and now have an index, request it
    // But only if we're still visible (not cancelled)
    if !hasRequestedAutoLoad,
       commentIndexMap[comment.id] != nil,
       autoLoadManager.isCommentVisible(comment.id) {
      print("[AUTO-LOAD \(Date().timeIntervalSinceReferenceDate)] Comment \(comment.id) retrying auto-load request after index update")
      requestAutoLoadSlot()
    }
  }
  
  private func startAutoLoadTimer() {
    // Don't start timer if already loading
    if loadMoreLoading { return }
        
    // Only start if we're the current auto-loading comment
    guard autoLoadManager.isCurrentlyAutoLoading(comment.id) else { return }
    
    print("[AUTO-LOAD \(Date().timeIntervalSinceReferenceDate)] TIMER STARTED \(comment.id))")
    // Reset progress
    withAnimation(.easeOut(duration: 0.1)) {
      autoLoadProgress = 0.0
    }
    
    // Start the progress timer
    let duration = getAutoLoadDuration()
    autoLoadTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { timer in
      DispatchQueue.main.async {
        // Check if we're still allowed to auto-load (not dragging, still our turn)
        guard autoLoadManager.isCurrentlyAutoLoading(comment.id) else {
          timer.invalidate()
          autoLoadTimer = nil
          autoLoadProgress = 0.0
          return
        }
        
        withAnimation {
          autoLoadProgress += timerInterval / duration
        }
        
        resetProgressTimer?.invalidate()
        
        if autoLoadProgress >= 1.0 {
          timer.invalidate()
          autoLoadTimer = nil
          resetProgressTimer = nil
          handleTap()
        } else {
          resetProgressTimer = Timer.scheduledTimer(withTimeInterval: 3 * timerInterval, repeats: false) { _ in
            if autoLoadTimer != nil {
              DispatchQueue.main.async {
                autoLoadProgress = 0
              }
            }
            
            resetProgressTimer = nil
          }
        }
      }
    }
  }
  
  private func cancelAutoLoadTimer() {
    autoLoadTimer?.invalidate()
    autoLoadTimer = nil
    resetProgressTimer?.invalidate()
    resetProgressTimer = nil
    autoLoadManager.stopAutoLoad(for: comment.id)
    // Use the new method to properly remove from all tracking
    autoLoadManager.markCommentCancelled(comment.id)
    hasRequestedAutoLoad = false
    withAnimation(.easeOut(duration: 0.2)) {
      autoLoadProgress = 0.0
    }
  }
  
  var body: some View {
    let theme = selectedTheme.comments
    let horPad = selectedTheme.comments.theme.innerPadding.horizontal
    
    if let data = comment.data, let count = data.count, let parentElement = parentElement, count > 0 {
      HStack(spacing: 0) {
        if data.depth != 0 && indentLines != 0 {
          HStack(alignment: .bottom, spacing: 6) {
            let shapes = Array(1...Int(indentLines ?? data.depth ?? 1))
            ForEach(shapes, id: \.self) { i in
              if arrowKinds.indices.contains(i - 1) {
                let actualArrowKind = arrowKinds[i - 1]
                Arrows(kind: actualArrowKind, offset: theme.theme.innerPadding.vertical + theme.theme.repliesSpacing)
              }
            }
          }
        }
        
        HStack(spacing: 8) {
          // Main Load More button
          HStack(spacing: 6) {
            Image(systemName: "plus.message.fill")
            HStack(spacing: 3) {
              HStack(spacing: 0) {
                Text("Load")
                if loadMoreLoading {
                  Text("ing")
                    .transition(.scale.combined(with: .opacity))
                }
              }
              Text(count == 0 ? "some" : String(count))
              HStack(spacing: 0) {
                Text("more")
                if loadMoreLoading {
                  Text("...")
                    .transition(.scale.combined(with: .opacity))
                }
              }
            }
            
            // Progress indicator only
            if autoLoadProgress > 0 && !loadMoreLoading {
              ZStack {
                Circle()
                  .stroke(selectedTheme.comments.theme.loadMoreText.color().opacity(0.3), lineWidth: 1)
                  .frame(width: 12, height: 12)
                
                Circle()
                  .trim(from: 0, to: autoLoadProgress)
                  .stroke(selectedTheme.comments.theme.loadMoreText.color(), lineWidth: 1.5)
                  .frame(width: 12, height: 12)
                  .rotationEffect(.degrees(-90))
                  .animation(.linear(duration: timerInterval), value: autoLoadProgress)
              }
            }
          }
          .padding(.vertical, selectedTheme.comments.theme.loadMoreInnerPadding.vertical)
          .padding(.horizontal, selectedTheme.comments.theme.loadMoreInnerPadding.horizontal)
          .opacity(loadMoreLoading ? 0.5 : 1)
          .background(Capsule(style: .continuous).fill(selectedTheme.comments.theme.loadMoreBackground()))
          .compositingGroup()
          .fontSize(selectedTheme.comments.theme.loadMoreText.size, selectedTheme.comments.theme.loadMoreText.weight.t)
          .foregroundColor(selectedTheme.comments.theme.loadMoreText.color())
          .background(
            // Hidden reference view to get the height
            GeometryReader { geometry in
              Color.clear
                .onAppear {
                  // Store the height for the cancel button
                }
            }
          )
          
          // Cancel button with expand/collapse animation
          if autoLoadProgress > 0 && !loadMoreLoading {
            Button(action: {
              cancelAutoLoadTimer()
            }) {
              Circle()
                .fill(selectedTheme.comments.theme.loadMoreBackground())
                .frame(
                  width: selectedTheme.comments.theme.loadMoreInnerPadding.vertical * 2 + selectedTheme.comments.theme.loadMoreText.size + 4,
                  height: selectedTheme.comments.theme.loadMoreInnerPadding.vertical * 2 + selectedTheme.comments.theme.loadMoreText.size + 4
                )
                .overlay(
                  Image(systemName: "xmark")
                    .font(.system(size: selectedTheme.comments.theme.loadMoreText.size * 0.8, weight: .semibold))
                    .foregroundColor(selectedTheme.comments.theme.loadMoreText.color())
                    .scaleEffect(autoLoadProgress > 0 ? 1.0 : 0.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: autoLoadProgress > 0)
                )
                .scaleEffect(autoLoadProgress > 0 ? 1.0 : 0.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: autoLoadProgress > 0)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Circle())
          }
        }
        .padding(.top, data.depth == 0 ? 0 : theme.theme.repliesSpacing)
        .padding(.vertical, max(0, theme.theme.innerPadding.vertical - (data.depth == 0 ? theme.theme.cornerRadius : 0)))
      }
      .padding(.horizontal, horPad)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(selectedTheme.comments.theme.bg())
      .contentShape(Rectangle())
      .onTapGesture {
        handleTap()
      }
      .allowsHitTesting(!loadMoreLoading)
      .id("\(comment.id)-more")
      .onAppear {
        print("[DEBUG] CommentLinkMore \(comment.id) appeared - depth: \(data.depth), topCommentIdx: \(topCommentIdx), hasIndex: \(commentIndexMap[comment.id] != nil)")
        
        if data.depth == 0 {
          handleTap()
          return
        }
        
        if NetworkMonitor.shared.connectedToWifi, let count = data.count, count == 1 {
          handleTap()
          return
        }
        
        // Request auto-load slot for other cases
        requestAutoLoadSlot()
      }
      .onDisappear {
        // Mark as invisible when view disappears
        autoLoadManager.markCommentInvisible(comment.id)
        // Cancel timer and remove from queue when view disappears
        cancelAutoLoadTimer()
      }
      .onChange(of: topCommentIdx) {
        // Use the new centralized handler instead of individual comment logic
        autoLoadManager.handleTopCommentIndexChange(topCommentIdx, commentIndexMap: commentIndexMap)
      }
      .onChange(of: commentIndexMap) {
        // Process any pending comments when index map updates
        autoLoadManager.processIndexMapUpdate(commentIndexMap)
        // Also check if this specific comment can now request auto-load
        handleIndexMapUpdate()
      }
      .onChange(of: autoLoadManager.isCurrentlyAutoLoading(comment.id)) {
        if !loadMoreLoading {
          // It's our turn to auto-load
          DispatchQueue.main.async {
            startAutoLoadTimer()
          }
        }
      }
    }
  }
}
