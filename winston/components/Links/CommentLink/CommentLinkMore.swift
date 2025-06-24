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
    private var queuedComments: [(id: String, index: Int)] = []
    
    private init() {}
    
    func canStartAutoLoad(for commentId: String, at index: Int) -> Bool {
        return currentAutoLoadingCommentId == nil
    }
    
    func requestAutoLoadSlot(for commentId: String, at index: Int) {
        // Add to queue if not already there
        if !queuedComments.contains(where: { $0.id == commentId }) {
            queuedComments.append((id: commentId, index: index))
            // Sort by index to prioritize comments higher up
            queuedComments.sort { $0.index < $1.index }
        }
        
        // Try to start the next comment if nothing is currently loading
        processQueue()
    }
    
    private func processQueue() {
      guard currentAutoLoadingCommentId == nil && !queuedComments.isEmpty else {
//          print("[AUTO-LOAD \(Date().timeIntervalSinceReferenceDate)] Cannot process queue - loading: \(currentAutoLoadingCommentId != nil), dragging: \(isDragging), queue empty: \(queuedComments.isEmpty)")
          return
      }
      
      // Get the comment with the lowest index (highest priority)
      let nextComment = queuedComments.removeFirst()
      currentAutoLoadingCommentId = nextComment.id

      // Force UI update
      DispatchQueue.main.async {
          self.objectWillChange.send()
      }
    }
    
    func startAutoLoad(for commentId: String) {
        currentAutoLoadingCommentId = commentId
    }
    
    func stopAutoLoad(for commentId: String) {
        if currentAutoLoadingCommentId == commentId {
            currentAutoLoadingCommentId = nil
            // Process next in queue immediately
            processQueue()
        }
    }
    
    func isCurrentlyAutoLoading(_ commentId: String) -> Bool {
        return currentAutoLoadingCommentId == commentId
    }
    
    func removeFromQueue(_ commentId: String) {
        queuedComments.removeAll { $0.id == commentId }
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
    guard let currentIndex = commentIndexMap[comment.id] else {
//      print("[AUTO-LOAD \(Date().timeIntervalSinceReferenceDate)] No index found for comment \(comment.id)")
      return
    }
    
//    print("[AUTO-LOAD \(Date().timeIntervalSinceReferenceDate)] Comment \(comment.id) requesting slot at index \(currentIndex)")
    hasRequestedAutoLoad = true
    autoLoadManager.requestAutoLoadSlot(for: comment.id, at: currentIndex)
  }
  
  private func startAutoLoadTimer() {
    // Don't start timer if already loading
    if loadMoreLoading { return }
        
    // Only start if we're the current auto-loading comment
    guard autoLoadManager.isCurrentlyAutoLoading(comment.id) else { return }
    
    print("[AUTO-LOAD \(Date().timeIntervalSinceReferenceDate)] TIMER STARTED \(comment.id))")
    // Reset progress
    autoLoadProgress = 0.0
    
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
        
        autoLoadProgress += timerInterval / duration
        
        resetProgressTimer?.invalidate()
        
        if autoLoadProgress >= 1.0 {
          timer.invalidate()
          autoLoadTimer = nil
          resetProgressTimer = nil
          handleTap()
        } else {
          resetProgressTimer = Timer.scheduledTimer(withTimeInterval: 2 * timerInterval, repeats: false) { _ in
            DispatchQueue.main.async {
              withAnimation(.easeOut(duration: 0.2)) {
                autoLoadProgress = 0.0
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
    autoLoadManager.stopAutoLoad(for: comment.id)
    autoLoadManager.removeFromQueue(comment.id)
    hasRequestedAutoLoad = false
    withAnimation(.easeOut(duration: 0.2)) {
      autoLoadProgress = 0.0
    }
  }
  
  // Helper to determine if this comment should be prioritized for auto-loading
  private func shouldPrioritizeAutoLoad() -> Bool {
    guard let data = comment.data else { return false }
    guard let currentIndex = commentIndexMap[comment.id] else { return false }
    
    // Skip auto-timer for top-level comments (depth 0)
    if data.depth == 0 { return false }
    
    // Skip single child comments on WiFi that are near the top
    if NetworkMonitor.shared.connectedToWifi, let count = data.count, count == 1 {
      if currentIndex <= topCommentIdx + 5 {
        return false // These will be loaded immediately anyway
      }
    }
    
    return true
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
          
          // Progress indicator (small circle after the text)
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
        .padding(.top, data.depth == 0 ? 0 : theme.theme.repliesSpacing)
        .padding(.vertical, max(0, theme.theme.innerPadding.vertical - (data.depth == 0 ? theme.theme.cornerRadius : 0)))
        .compositingGroup()
        .fontSize(selectedTheme.comments.theme.loadMoreText.size, selectedTheme.comments.theme.loadMoreText.weight.t)
        .foregroundColor(selectedTheme.comments.theme.loadMoreText.color())
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
        if data.depth == 0 {
          handleTap()
          return
        }
        
        if NetworkMonitor.shared.connectedToWifi, let count = data.count, count == 1 {
          handleTap()
          return
        }
        
        // Request auto-load slot for other cases
        if shouldPrioritizeAutoLoad() {
          requestAutoLoadSlot()
        }
      }
      .onDisappear {
        // Cancel timer and remove from queue when view disappears
        cancelAutoLoadTimer()
      }
      .onChange(of: topCommentIdx) {
        if let currentIndex = commentIndexMap[comment.id], currentIndex < topCommentIdx {
          cancelAutoLoadTimer()
        }
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
