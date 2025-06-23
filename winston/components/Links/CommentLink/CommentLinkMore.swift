//
//  CommentLinkMore.swift
//  winston
//
//  Created by Igor Marcossi on 17/07/23.
//

import SwiftUI
import Defaults

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
  
  @SilentState var loadMoreTimer: Timer? = nil
  @State var loadMoreLoading = false
  @State var autoLoadProgress: Double = 0.0
  @State var autoLoadTimer: Timer? = nil
  
  @Environment(\.useTheme) private var selectedTheme
  
  private let timerInterval: TimeInterval = 0.1
  
  private func getAutoLoadDuration() -> TimeInterval {
    return NetworkMonitor.shared.connectedToWifi ? 2.5 : 4
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
  
  private func startAutoLoadTimer() {
    // Don't start timer if already loading or for top-level comments or single child comments
    if loadMoreLoading { return }
    
    guard let data = comment.data else { return }
    
    // Skip auto-timer for top-level comments (depth 0) or single child comments
    if data.depth == 0 { return }
    if NetworkMonitor.shared.connectedToWifi, let count = data.count, count == 1 {
      if (commentIndexMap[comment.id] ?? 9999) >= topCommentIdx {
        return // These will be loaded immediately anyway
      }
    }
    
    // Reset progress
    autoLoadProgress = 0.0
    
    // Start the progress timer
    let duration = getAutoLoadDuration()
    autoLoadTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { timer in
      DispatchQueue.main.async {
        autoLoadProgress += timerInterval / duration
        
        if autoLoadProgress >= 1.0 {
          timer.invalidate()
          autoLoadTimer = nil
          handleTap()
        }
      }
    }
  }
  
  private func cancelAutoLoadTimer() {
    autoLoadTimer?.invalidate()
    autoLoadTimer = nil
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
                .stroke(selectedTheme.comments.theme.loadMoreText.color().opacity(0.3), lineWidth: 1.5)
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
          if (commentIndexMap[comment.id] ?? 9999) >= topCommentIdx {
            handleTap()
            return
          }
        }
        
        // Start auto-load timer for other cases
        startAutoLoadTimer()
      }
      .onDisappear {
        // Cancel timer when view disappears
        cancelAutoLoadTimer()
      }
      .onChange(of: topCommentIdx) {
        if (commentIndexMap[comment.id] ?? 9999) < topCommentIdx {
          cancelAutoLoadTimer()
        }
      }
    }
  }
}
