//
//  SeenPostsPanel.swift
//  winston
//
//  Created on [Date]
//

import SwiftUI
import Defaults

struct SeenPostsPanel: View {
    @Environment(\.useTheme) private var theme
    @State private var seenSubreddits: [SeenSubreddit] = []
    @State private var totalPosts = 0
    @State private var oldPostsCount = 0
    @State private var showingClearAllAlert = false
    @State private var showingClearSubredditAlert = false
    @State private var selectedSubredditToClear: SeenSubreddit?
    
    var sortedSubreddits: [SeenSubreddit] {
        return seenSubreddits.sorted { $0.postIds.count > $1.postIds.count }
    }
    
    var body: some View {
        List {
            Section("Statistics") {
                HStack {
                    Text("Total Subreddits")
                    Spacer()
                    Text("\(seenSubreddits.count)")
                        .opacity(0.6)
                }
                
                HStack {
                    Text("Total Seen Posts")
                    Spacer()
                    Text("\(totalPosts)")
                        .opacity(0.6)
                }
                
                HStack {
                    Text("Old Posts (>7 days)")
                    Spacer()
                    Text("\(oldPostsCount)")
                        .opacity(0.6)
                }
            }
            .themedListSection()
            
            Section {
                HStack {
                    Text("Clean Up Old Posts")
                    Spacer()
                    Button(action: cleanupOldPosts) {
                        Image(systemName: "trash.slash")
                            .foregroundColor(.blue)
                    }
                }
                
                HStack {
                    Text("Clear All Seen Posts")
                    Spacer()
                    Button(action: { showingClearAllAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            } header: {
                Text("Actions")
            }
            .themedListSection()
            
            Section {
                if sortedSubreddits.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 40))
                                .opacity(0.3)
                            Text("No seen posts yet")
                                .opacity(0.6)
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                } else {
                    ForEach(sortedSubreddits, id: \.subId) { subreddit in
                        ZStack {
                            HStack(alignment: .center) {
                                Text("r/\(subreddit.subId)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eye.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 14))
                                        Text("\(subreddit.postIds.count)")
                                            .foregroundColor(.primary)
                                            .font(.body)
                                    }
                                    
                                    if let recentDate = getMostRecentSeenDate(for: subreddit) {
                                        Text(formatDate(recentDate))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // Dotted line background
                            GeometryReader { geometry in
                                Path { path in
                                    let y = geometry.size.height / 2
                                    var x = 120.0 // Start after subreddit name
                                    let endX = geometry.size.width - 80 // End before stats
                                    
                                    while x < endX {
                                        path.addEllipse(in: CGRect(x: x, y: y - 1, width: 2, height: 2))
                                        x += 6
                                    }
                                }
                                .fill(Color.secondary.opacity(0.3))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Navigate to detailed view if needed
                        }
                    }
                    .onDelete(perform: deleteSubreddits)
                }
            } header: {
                if !seenSubreddits.isEmpty {
                    Text("Subreddits (\(sortedSubreddits.count))")
                }
            }
            .themedListSection()
        }
        .themedListBG(theme.lists.bg)
        .navigationTitle("Seen Posts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSeenPostsData()
        }
        .refreshable {
            loadSeenPostsData()
        }
        .alert("Clear All Seen Posts", isPresented: $showingClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllSeenPosts()
            }
        } message: {
            Text("This will permanently clear all seen posts for all subreddits. This action cannot be undone.")
        }
        .alert("Clear Seen Posts", isPresented: $showingClearSubredditAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                if let subreddit = selectedSubredditToClear {
                    clearSeenPosts(for: subreddit)
                }
            }
        } message: {
            if let subreddit = selectedSubredditToClear {
                Text("This will permanently clear all \(subreddit.postIds.count) seen posts for r/\(subreddit.subId). This action cannot be undone.")
            }
        }
    }
    
    private func getMostRecentSeenDate(for subreddit: SeenSubreddit) -> Date? {
        let seenPostsWithDates = SeenSubredditManager.shared.getSeenPostsWithDates(for: subreddit.subId)
        return seenPostsWithDates.values.max()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func deleteSubreddits(at offsets: IndexSet) {
        for index in offsets {
            let subreddit = sortedSubreddits[index]
            SeenSubredditManager.shared.deleteSeenSubreddit(subId: subreddit.subId)
        }
        loadSeenPostsData()
    }
    
    private func loadSeenPostsData() {
        let manager = SeenSubredditManager.shared
        seenSubreddits = manager.getAllSeenSubreddits()
        
        let stats = manager.getSeenPostsStatistics()
        totalPosts = stats.totalPosts
        oldPostsCount = stats.oldPosts
    }
    
    private func cleanupOldPosts() {
        SeenSubredditManager.shared.cleanupOldPosts()
        loadSeenPostsData()
    }
    
    private func clearAllSeenPosts() {
        let manager = SeenSubredditManager.shared
        for subreddit in seenSubreddits {
            manager.clearSeenPosts(for: subreddit.subId)
        }
        loadSeenPostsData()
    }
    
    private func clearSeenPosts(for subreddit: SeenSubreddit) {
        SeenSubredditManager.shared.deleteSeenSubreddit(subId: subreddit.subId)
        loadSeenPostsData()
        selectedSubredditToClear = nil
    }
}

struct SubredditSeenRow: View {
    let subreddit: SeenSubreddit
    let onClear: () -> Void
    
    @State private var showingSeenDates = false
    
    var body: some View {
        HStack {
            Image(systemName: "eye.fill")
                .foregroundColor(.secondary)
            
            Text("\(subreddit.postIds.count)")
                .foregroundColor(.secondary)
            
            Image(systemName: "clock")
                .foregroundColor(.secondary)
            
            if let recentDate = getMostRecentSeenDate() {
                Text(formatDate(recentDate))
                    .foregroundColor(.secondary)
            } else {
                Text("No posts")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onClear) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .contentShape(Rectangle())

        .sheet(isPresented: $showingSeenDates) {
            SeenPostsDatesView(subreddit: subreddit)
        }
    }
    
    private func getMostRecentSeenDate() -> Date? {
        let seenPostsWithDates = SeenSubredditManager.shared.getSeenPostsWithDates(for: subreddit.subId)
        return seenPostsWithDates.values.max()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SeenPostsDatesView: View {
    let subreddit: SeenSubreddit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.useTheme) private var theme
    
    @State private var seenPostsWithDates: [String: Date] = [:]
    @State private var searchText = ""
    
    var sortedPosts: [(postId: String, date: Date)] {
        let filtered = searchText.isEmpty ? seenPostsWithDates : seenPostsWithDates.filter { $0.key.localizedCaseInsensitiveContains(searchText) }
        return filtered.map { (postId: $0.key, date: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(sortedPosts, id: \.postId) { post in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.postId)
                                .font(.system(.body, design: .monospaced))
                            
                            HStack {
                                Label(formatFullDate(post.date), systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if Calendar.current.dateInterval(of: .day, for: post.date)?.start ?? Date() < Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() {
                                    Text("Old")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Remove", systemImage: "trash") {
                                removePost(post.postId)
                            }
                            .tint(.red)
                        }
                    }
                } header: {
                    Text("Seen Posts (\(sortedPosts.count))")
                } footer: {
                    if sortedPosts.isEmpty && !searchText.isEmpty {
                        Text("No posts found matching '\(searchText)'")
                    }
                }
            }
            .themedListBG(theme.lists.bg)
            .navigationTitle("r/\(subreddit.subId)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search post IDs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSeenPosts()
        }
    }
    
    private func loadSeenPosts() {
        seenPostsWithDates = SeenSubredditManager.shared.getSeenPostsWithDates(for: subreddit.subId)
    }
    
    private func removePost(_ postId: String) {
        SeenSubredditManager.shared.removeSeenPost(subId: subreddit.subId, postId: postId)
        loadSeenPosts()
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
