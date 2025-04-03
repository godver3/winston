//
//  Post.swift
//  winston
//
//  Created by Igor Marcossi on 28/06/23.
//

import SwiftUI
import Defaults
import AVFoundation
import AlertToast

struct PostView: View, Equatable {
  static func == (lhs: PostView, rhs: PostView) -> Bool {
    lhs.post == rhs.post && lhs.subreddit.id == rhs.subreddit.id && lhs.hideElements == rhs.hideElements && lhs.ignoreSpecificComment == rhs.ignoreSpecificComment && lhs.sort == rhs.sort && lhs.update == rhs.update && lhs.comments.count == rhs.comments.count && lhs.searchOpen == rhs.searchOpen && lhs.unseenSkipperOpen == rhs.unseenSkipperOpen && lhs.searchFocused == rhs.searchFocused && lhs.searchQuery.value == rhs.searchQuery.value && lhs.searchQuery.debounced == rhs.searchQuery.debounced && lhs.currentMatchIndex == rhs.currentMatchIndex && lhs.searchMatches == rhs.searchMatches
  }
  
  var post: Post
  var subreddit: Subreddit
  var forceCollapse: Bool
  var highlightID: String?
  @Default(.PostPageDefSettings) private var defSettings
  @Default(.CommentsSectionDefSettings) var commentsSectionDefSettings
  @Environment(\.useTheme) private var selectedTheme
  @Environment(\.globalLoaderStart) private var globalLoaderStart
  @State private var ignoreSpecificComment = false
  @State private var hideElements = true
  @State private var sort: CommentSortOption
  @State private var update = false
  
  @SilentState private var topVisibleCommentId: String? = nil
  @SilentState private var previousScrollTarget: String? = nil
  @State private var comments: [Comment] = []
  @State private var flattened: [Comment] = []
  @State private var matches: [Comment] = []
  @State private var seenComments: String? = nil
    
  @State private var searchQuery = Debouncer("", delay: 0.25)
  @State private var searchOpen = false
  @State private var unseenSkipperOpen = false
  @State private var searchMatches = 0
  @State private var currentMatchIndex = 0
  @State private var indexOfFirstMatch = 99999
  @State private var currentMatchId = ""
  @State private var visibleComments = Debouncer("", delay: 0.25)
  @State private var scrolling: Bool = false
  
  @FocusState private var searchFocused: Bool

  
  init(post: Post, subreddit: Subreddit, forceCollapse: Bool = false, highlightID: String? = nil) {
    self.post = post
    self.subreddit = subreddit
    self.forceCollapse = forceCollapse
    self.highlightID = highlightID
    
    let defSettings = Defaults[.PostPageDefSettings]
    let commentsDefSettings = Defaults[.CommentsSectionDefSettings]
    
    let title = post.data?.title.lowercased() ?? ""
    let defaultSort = title.contains("game thread") && !title.contains("post game thread") ?
      CommentSortOption.live : commentsDefSettings.preferredSort
    _sort = State(initialValue: defSettings.perPostSort ? (defSettings.postSorts[post.id] ?? defaultSort) : defaultSort);
  }
  
  func asyncFetch(_ full: Bool = true) async {
    if full {
      update.toggle()
    }
    if let result = await post.refreshPost(commentID: ignoreSpecificComment ? nil : highlightID, sort: sort, after: nil, subreddit: subreddit.data?.display_name ?? subreddit.id, full: full), let newComments = result.0 {
            
      Task(priority: .background) {
        await RedditAPI.shared.updateCommentsWithAvatar(comments: newComments, avatarSize: selectedTheme.comments.theme.badge.avatar.size)
      }
      
      Task(priority: .background) {
        if let numComments = post.data?.num_comments {
          await post.saveCommentsCount(numComments: numComments)
        }
      }
    }
  }
  
  func updatePost() {
    Task(priority: .background) { await asyncFetch(true) }
  }
  
  func openUnseenSkipper(_ reader: ScrollViewProxy) {
    guard let seenComments else { return }
    
    if !seenComments.isEmpty {
      unseenSkipperOpen = true
      currentMatchId = ""
      
      updateMatches(reader)
    }
  }

  func refreshComments() {
    Task { await asyncFetch() }
  }
  
  func updateVisibleComments(_ id: String, _ visible: Bool) {
    let key = "|\(id)|"
    
    if visible {
      visibleComments.value += key
    } else {
      visibleComments.value = visibleComments.value.replacingOccurrences(of: key, with: "")
    }
  }
  
  func updateMatchIndex(_ visible: String) {
    if let lastMatchIndex = matches.lastIndex(where: { comment in visible.contains("|\(comment.id)|") }) {
      DispatchQueue.main.async {
        withAnimation {
          currentMatchIndex = lastMatchIndex + 1
          currentMatchId = matches[lastMatchIndex].id
        }
      }
    } else if visible.isEmpty || flattened.lastIndex(where: { comment in visible.contains("|\(comment.id)|") })! < indexOfFirstMatch {
      DispatchQueue.main.async {
        withAnimation {
          currentMatchIndex = 0
          currentMatchId = ""
        }
      }
    }
  }
  
  func newCommentsLoaded() {
    flattened = CommentUtils.shared.flattenComments(comments)
    updateMatches()
  }
  
  func updateMatches(_ reader: ScrollViewProxy? = nil) {
    let query = searchQuery.debounced
    
    if (searchOpen && query.isEmpty) || (unseenSkipperOpen && (seenComments == nil || seenComments!.isEmpty)) {
      DispatchQueue.main.async {
        withAnimation {
          currentMatchIndex = 0
          searchMatches = 0
        }
      }
      
      return
    }
    
    matches = searchOpen ? getMatchingComments(query) : getUnseenComments()
    indexOfFirstMatch = flattened.firstIndex(where: { flat in matches.contains(where: { match in match.id == flat.id })}) ?? 99999
    
    DispatchQueue.main.async {
      withAnimation {
        searchMatches = matches.count
      }
    }
    
    scrollToNextMatch(true, reader)
  }
  
  func getMatchingComments(_ query: String) -> [Comment] {
    return flattened.filter({ ($0.data?.body ?? "").lowercased().contains(query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))})
  }
  
  func getUnseenComments() -> [Comment] {
    guard let seenComments else { return [] }
    return flattened.filter({ !seenComments.contains($0.data?.id ?? "") })
  }
  
  func startScrolling (forward: Bool) {
    scrolling = true
    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
      scrolling = false
      if forward { updateMatchIndex(visibleComments.value) }
    }
  }
  
  func scrollToNextMatch (_ forward: Bool = true, _ reader: ScrollViewProxy? = nil) {
    if searchOpen && searchQuery.debounced.isEmpty { return }
        
    if matches.isEmpty {
      DispatchQueue.main.async {
        withAnimation {
          currentMatchIndex = 0
        }
      }
      
      return
    }
    
    var currIndex = 0
    var targetIndex = 0

    if !currentMatchId.isEmpty {
      currIndex = matches.firstIndex(where: { $0.id == currentMatchId }) ?? 0
      targetIndex = forward ? (currIndex + 1 > matches.count - 1 ? 0 : currIndex + 1) : (currIndex - 1 < 0 ? matches.count - 1 : currIndex - 1)
    }
    
    currentMatchId = matches[targetIndex].id

    startScrolling(forward: forward)
    DispatchQueue.main.async {
      withAnimation {
        currentMatchIndex = targetIndex + 1
        reader?.scrollTo(currentMatchId, anchor: .top)
      }
    }
  }

  var body: some View {
    let navtitle: String = post.data?.title ?? "no title"
    let subnavtitle: String = "r/\(post.data?.subreddit ?? "no sub") \u{2022} " + String(localized:"\(post.data?.num_comments ?? 0) comments")
    let commentsHPad = selectedTheme.comments.theme.outerHPadding > 0 ? selectedTheme.comments.theme.outerHPadding : selectedTheme.comments.theme.innerPadding.horizontal
    GeometryReader { geometryReader in
      ScrollViewReader { proxy in
        List {
          Group {
            Section {
              if let winstonData = post.winstonData {
                PostContent(post: post, winstonData: winstonData, sub: subreddit, forceCollapse: forceCollapse)
              }
              //              .equatable()
              
              if selectedTheme.posts.inlineFloatingPill {
                PostFloatingPill(post: post, subreddit: subreddit, showUpVoteRatio: defSettings.showUpVoteRatio)
                  .padding(-10)
              }
              
              HStack (spacing: 6){
                Text("Comments")
                  .fontSize(20, .bold)
                
                Spacer()
                
                Menu {
                  if !hideElements {
                    ForEach(CommentSortOption.allCases) { opt in
                      Button {
                        sort = opt
                        Defaults[.PostPageDefSettings].postSorts[post.id] = opt
                      } label: {
                        HStack {
                          Text(opt.rawVal.value.capitalized)
                          Spacer()
                          Image(systemName: opt.rawVal.icon)
                            .foregroundColor(Color.accentColor)
                            .fontSize(17, .bold)
                        }
                      }
                    }
                  }
                } label: {
                  Image(systemName: sort.rawVal.icon)
                    .foregroundColor(Color.accentColor)
                    .fontSize(17, .bold)
                }
                
              }.frame(maxWidth: .infinity, alignment: .leading)
                .id("comments-header")
                .listRowInsets(EdgeInsets(top: selectedTheme.posts.commentsDistance / 2, leading:commentsHPad, bottom: 8, trailing: commentsHPad))
              
            }
            .listRowBackground(Color.clear)
            
            if !hideElements {
              PostReplies(update: update, post: post, subreddit: subreddit, ignoreSpecificComment: ignoreSpecificComment, highlightID: highlightID, sort: sort, proxy: proxy, geometryReader: geometryReader, topVisibleCommentId: $topVisibleCommentId, previousScrollTarget: $previousScrollTarget, comments: $comments, seenComments: $seenComments, fadeSeenComments: $unseenSkipperOpen, searchQuery: searchQuery.debounced, currentMatchId: currentMatchId, newCommentsLoaded: newCommentsLoaded, updateVisibleComments: updateVisibleComments)
            }
            
            if !ignoreSpecificComment && highlightID != nil {
              Section {
                Button {
                  globalLoaderStart("Loading full post...")
                  withAnimation {
                    ignoreSpecificComment = true
                  }
                } label: {
                  HStack {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("View full conversation")
                  }
                }
              }
              .listRowBackground(Color.primary.opacity(0.1))
            }
            
            Section {
              Spacer()
                .frame(maxWidth: .infinity, minHeight: 72)
                .listRowBackground(Color.clear)
                .id("end-spacer")
            }
          }
          .listRowSeparator(.hidden)
        }
        .scrollIndicators(.never)
        .themedListBG(selectedTheme.posts.bg)
        .transition(.opacity)
        .environment(\.defaultMinListRowHeight, 1)
        .listStyle(.plain)
        .refreshable {
          refreshComments()
        }
        .overlay(alignment: .bottomTrailing) {
          if !selectedTheme.posts.inlineFloatingPill {
            PostFloatingPill(post: post, subreddit: subreddit, showUpVoteRatio: defSettings.showUpVoteRatio)
          }
        }
        .overlay(alignment: .bottom) {
          VStack(spacing: 8) {
            
            if searchOpen {
              HStack {
                TextField("Search comments...", text: $searchQuery.value)
                  .fontSize(17)
                  .focused($searchFocused)
                  .foregroundColor(Color.hex("7D7E80"))
                  .onChange(of: searchQuery.debounced) { _, val in
                    currentMatchId = ""
                    updateMatches(proxy)
                  }
                
                Spacer()
              }
            }
            
            HStack(spacing: 12) {
              
              if unseenSkipperOpen {
                PostLinkGlowDot(unseenType: .dot(selectedTheme.comments.theme.unseenDot), seen: false, badge: true).equatable()
              }
              
              Text("\(currentMatchIndex)/\(searchMatches)")
                .fontSize(16, .semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.hex("2C2E32").clipShape(RoundedRectangle(cornerRadius:12)))
                .foregroundStyle(Color(UIColor(hex: "7D7E80")))
                .lineLimit(1)
              
              HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                  .fontSize(16, .semibold)
                  .foregroundStyle(Color(UIColor(hex: "7D7E80")))
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .background(Color.hex("2C2E32").clipShape(RoundedRectangle(cornerRadius:12)))
                  .onTapGesture {
                    Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                    scrollToNextMatch(false, proxy)
                  }
                
                Image(systemName: "chevron.right")
                  .fontSize(16, .semibold)
                  .foregroundStyle(Color(UIColor(hex: "7D7E80")))
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .background(Color.hex("2C2E32").clipShape(RoundedRectangle(cornerRadius:12)))
                  .onTapGesture {
                    Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                    scrollToNextMatch(true, proxy)
                  }
              }
              
              Spacer()
              
              Image(systemName: "chevron.down")
                .opacity(searchFocused ? 1 : 0)
                .fontSize(16, .semibold)
                .foregroundStyle(Color(UIColor(hex: "7D7E80")))
                .padding([.trailing], 4)
                .onTapGesture {
                  Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                  DispatchQueue.main.async {
                    withAnimation {
                      searchFocused = false
                    }
                  }
                }
              
              Image(systemName: "xmark")
                .fontSize(16, .semibold)
                .foregroundStyle(Color(UIColor(hex: "7D7E80")))
                .padding([.trailing], 4)
                .onTapGesture {
                  Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                  
                  if searchFocused {
                    DispatchQueue.main.async {
                      withAnimation {
                        searchFocused = false
                      }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                      withAnimation {
                        searchOpen = false
                        searchQuery.value = ""
                      }
                    }
                  } else {
                    DispatchQueue.main.async {
                      withAnimation {
                        searchQuery.value = ""
                        searchOpen = false
                        unseenSkipperOpen = false
                      }
                    }
                  }
                }
              
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 15)
          .frame(maxWidth: searchOpen || unseenSkipperOpen ? .infinity : 0)
          .animation(.bouncy(duration: 0.5), value: searchOpen || unseenSkipperOpen)
          .background(Color.hex("212326").clipShape(RoundedRectangle(cornerRadius:20)))
          .shadow(color: Color.hex("212326"), radius: 10)
          .opacity(searchOpen || unseenSkipperOpen ? 1 : 0)
          .animation(.bouncy(duration: 0.5), value: searchOpen || unseenSkipperOpen)
          .padding(.horizontal, 8)
          .padding([.bottom], 8)
          .ignoresSafeArea(.keyboard)
          
        }
        .navigationBarTitle("\(navtitle)", displayMode: .inline)
        .toolbar { Toolbar(title: navtitle, subtitle: subnavtitle, hideElements: hideElements, subreddit: subreddit, post: post, searchOpen: $searchOpen, unseenSkipperOpen: $unseenSkipperOpen, searchFocused: _searchFocused) }
        .onChange(of: sort) { _, val in
          updatePost()
        }
        .onChange(of: comments) { _, val in
          Task {
            newCommentsLoaded()
          }
        }
        .onChange(of: visibleComments.debounced) { _, val in
          updateMatchIndex(val)
        }
        .onAppear {
          doThisAfter(0.5) {
            hideElements = false
            doThisAfter(0.1) {
              if highlightID != nil { withAnimation { proxy.scrollTo("loading-comments") } }
            }
          }
          if post.data == nil {
            updatePost()
          }
          
          
          Task(priority: .background) {
            if let numComments = post.data?.num_comments {
              await post.saveCommentsCount(numComments: numComments)
            }
          }
          
          Task(priority: .background) {
            if subreddit.data == nil && subreddit.id != "home" {
              await subreddit.refreshSubreddit()
            }
          }
        }
        .onPreferenceChange(CommentUtils.AnchorsKey.self) { anchors in
          Task(priority: .background) {
            topVisibleCommentId = CommentUtils.shared.topCommentRow(of: anchors, in: geometryReader)
          }
        }
        .commentSkipper(
          showJumpToNextCommentButton: $commentsSectionDefSettings.commentSkipper,
          topVisibleCommentId: $topVisibleCommentId,
          previousScrollTarget: $previousScrollTarget,
          comments: comments,
          reader: proxy,
          refresh: refreshComments,
          openUnseenSkipper : openUnseenSkipper,
          searchOpen: $searchOpen,
          unseenSkipperOpen: $unseenSkipperOpen
        )
      }
    }
  }
}

private struct Toolbar: ToolbarContent {
  var title: String
  var subtitle: String
  var hideElements: Bool
  var subreddit: Subreddit
  var post: Post
  @Binding var searchOpen: Bool
  @Binding var unseenSkipperOpen: Bool
  @FocusState var searchFocused: Bool
  
  var body: some ToolbarContent {
    if !IPAD {
      ToolbarItem(id: "postview-title", placement: .principal) {
        VStack {
          Text(title)
            .font(.headline)
          Text(subtitle)
            .font(.subheadline)
        }
      }
    }
    
    ToolbarItem(id: "postview-search-and-sub", placement: .navigationBarTrailing) {
      HStack {
        Image(systemName: "magnifyingglass")
          .fontSize(16, .semibold)
          .foregroundStyle(Color.white)
          .padding([.trailing], 4)
          .opacity(searchOpen ? 0 : 0.8)
          .onTapGesture {
            Hap.shared.play(intensity: 0.75, sharpness: 0.9)
            if !searchOpen {
              DispatchQueue.main.async {
                withAnimation {
                  searchOpen = true
                  unseenSkipperOpen = false
                }
              }
              
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                  searchFocused = true
                }
              }
            }
          }
        
        if let data = subreddit.data, !feedsAndSuch.contains(subreddit.id) {
          SubredditIcon(subredditIconKit: data.subredditIconKit)
            .onTapGesture { Nav.to(.reddit(.subInfo(subreddit))) }
        }
      }
    }
  }
}
