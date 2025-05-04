//
//  PostReplies.swift
//  winston
//
//  Created by Igor Marcossi on 31/07/23.
//

import SwiftUI
import Defaults
  
struct PostReplies: View {
  var update: Bool
  var post: Post
  var subreddit: Subreddit
  var ignoreSpecificComment: Bool
  var highlightID: String?
  var sort: CommentSortOption
  var proxy: ScrollViewProxy
  var geometryReader: GeometryProxy
  @Environment(\.useTheme) private var selectedTheme
  
  
  // MARK: Properties related to comment skipper
  @Binding var topVisibleCommentId: String?
  @Binding var previousScrollTarget: String?
  @Binding var comments: [Comment]
  @Binding var matchMap: [String: String]
  @Binding var seenComments: String?
  @Binding var fadeSeenComments: Bool
  @Binding var highlightCurrentMatch: Bool
  
  var searchQuery: String? = nil
  var currentMatchId: String? = nil
  var newCommentsLoaded: () -> Void
  var updateVisibleComments: (String, Bool) -> Void
  
  @State private var initialLoading = true
  @State private var loading = false
  @Environment(\.globalLoaderDismiss) private var globalLoaderDismiss
  
//  init(update: Bool, post: Post, subreddit: Subreddit, ignoreSpecificComment: Bool, highlightID: String?, sort: CommentSortOption, proxy: ScrollViewProxy, geometryReader: GeometryProxy, topVisibleCommentId: Binding<String?>, previousScrollTarget: Binding<String?>, comments: Binding<[Comment]>, matchMap: Binding<[String: String]>, seenComments: Binding<String?>, fadeSeenComments: Binding<Bool>, highlightCurrentMatch: Binding<Bool>, searchQuery: String?, currentMatchId: String?, newCommentsLoaded: @escaping () -> Void, updateVisibleComments: @escaping (String, Bool) -> Void) {
//    self.update = update
//    self.post = post
//    self.subreddit = subreddit
//    self.ignoreSpecificComment = ignoreSpecificComment
//    self.highlightID = highlightID
//    self.sort = sort
//    self.proxy = proxy
//    self.geometryReader = geometryReader
//    self._topVisibleCommentId = topVisibleCommentId
//    self._previousScrollTarget = previousScrollTarget
//    self._comments = comments
//    self._matchMap = matchMap
//    self._seenComments = seenComments
//    self._fadeSeenComments = fadeSeenComments
//    self._highlightCurrentMatch = highlightCurrentMatch
//    self.searchQuery = searchQuery
//    self.currentMatchId = currentMatchId
//    self.newCommentsLoaded = newCommentsLoaded
//    self.updateVisibleComments = updateVisibleComments
//    
//    if !loading && (comments.count == 0 || post.data == nil) {
//      Task(priority: .background) { [self] in
//        await asyncFetch(post.data == nil)
//      }
//    }
//  }
  
  func asyncFetch(_ full: Bool, _ altIgnoreSpecificComment: Bool? = nil) async {
   loading = true 
    
    if let result = await post.refreshPost(commentID: (altIgnoreSpecificComment ?? ignoreSpecificComment) ? nil : highlightID, sort: sort, after: nil, subreddit: subreddit.data?.display_name ?? subreddit.id, full: full), let newComments = result.0 {
        Task(priority: .background) {
          _ = await RedditAPI.shared.updateCommentsWithAvatar(comments: newComments, avatarSize: selectedTheme.comments.theme.badge.avatar.size)
        }
        newComments.forEach { $0.parentWinston = comments }
        await MainActor.run {
          withAnimation {
            comments = newComments
            initialLoading = false
            loading = false
          }
          
          newCommentsLoaded()

          if var specificID = highlightID {
            specificID = specificID.hasPrefix("t1_") ? String(specificID.dropFirst(3)) : specificID
            doThisAfter(0.1) {
              withAnimation(spring) {
                proxy.scrollTo("\(specificID)-body", anchor: .center)
              }
            }
          }
        }
      } else {
        await MainActor.run {
          withAnimation {
            initialLoading = false
            loading = false
          }
        }
    }
  }
  
  var body: some View {
    let theme = selectedTheme.comments
    let horPad = theme.theme.outerHPadding
    Group {
      let postFullname = post.data?.name ?? ""
      Group {
        ForEach(Array(comments.enumerated()), id: \.element.id) { i, comment in
          Section {
            
            CommentLinkDecoration(top: true, comment: comment, currentMatchId: currentMatchId, highlightCurrentMatch: highlightCurrentMatch, theme: theme)
              .id("\(comment.id)-top-decoration")
            
            if let commentWinstonData = comment.winstonData {
              CommentLink(highlightID: ignoreSpecificComment ? nil : highlightID, post: post, subreddit: subreddit, postFullname: postFullname, seenComments: seenComments, fadeSeenComments: fadeSeenComments, parentElement: .post($comments), comment: comment, commentWinstonData: commentWinstonData, children: comment.childrenWinston, searchQuery: searchQuery, matchMap: matchMap, isMatch: matchMap[comment.id] != nil, currentMatchId: currentMatchId, highlightCurrentMatch: highlightCurrentMatch, newCommentsLoaded: newCommentsLoaded, updateVisibleComments: updateVisibleComments, isLast: i == comments.count - 1)
                .id(comment.id)
                .if(comments.firstIndex(of: comment) != nil) { view in
                  view.anchorPreference(
                    key: CommentUtils.AnchorsKey.self,
                    value: .top
                  ) { [comment.id: $0] }
                }
            }
            
            CommentLinkDecoration(top: false, comment: comment, currentMatchId: currentMatchId, highlightCurrentMatch: highlightCurrentMatch, theme: theme)
              .id("\(comment.id)-bot-decoration")
            
            if comments.count - 1 != i {
              NiceDivider(divider: theme.divider)
                .id("\(comment.id)-bot-divider")
            }
            
          }
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets(top: 0, leading: horPad, bottom: 0, trailing: horPad))
        }
        Section {
          Spacer()
            .frame(height: 1)
            .listRowBackground(Color.clear)
            .onChange(of: update) { _ in
              Task(priority: .background) {
                await asyncFetch(true)
              }
            }
            .onChange(of: ignoreSpecificComment) { val in
              Task(priority: .background) {
                await asyncFetch(post.data == nil, val)
                globalLoaderDismiss()
              }
              if val {
                withAnimation(spring) {
                  proxy.scrollTo("post-content", anchor: .bottom)
                }
              }
            }
            .id("on-change-spacer")
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
      }
      .onAppear {
        if !loading && (comments.count == 0 || post.data == nil) {
          Task(priority: .background) {
            await asyncFetch(post.data == nil)
            
            DispatchQueue.main.async {
              withAnimation {
                seenComments = post.winstonData?.seenComments
                
                if let seen = seenComments, !seen.isEmpty {
                  // Open unseen skipper automatically
//                      fadeSeenComments = true
                }
              }
            }
          }
        } else {
          withAnimation {
            seenComments = post.winstonData?.seenComments
            
            if let seen = seenComments, !seen.isEmpty {
              // Open unseen skipper automatically
              fadeSeenComments = true
            }
          }
        }
      }
      
      if initialLoading {
        ProgressView()
          .progressViewStyle(.circular)
          .frame(maxWidth: .infinity, minHeight: 100 )
          .listRowBackground(Color.clear)
          .id("loading-comments")
      } else if comments.count == 0 {
        Text(QuirkyMessageUtil.noCommentsFoundMessage())
          .frame(maxWidth: .infinity, minHeight: 300)
          .opacity(0.25)
          .listRowBackground(Color.clear)
          .multilineTextAlignment(.center)
          .id("no-comments-placeholder")
      }
    }
  }
}
