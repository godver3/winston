//
//  DebugPanel.swift
//  winston
//
//  Created by Assistant on 2024.
//

import SwiftUI
import Defaults

struct DebugPanel: View {
  @Environment(\.useTheme) private var theme
  @State private var isLoading = false
  @State private var lastError: String?
  @State private var lastSuccess: String?
  
  var body: some View {
    List {
      Section("API Testing") {
        WListButton {
          if !isLoading {
            testFetchSubreddits()
          }
        } label: {
          HStack {
            Label("Test Fetch Subreddits", systemImage: "list.bullet")
            if isLoading {
              Spacer()
              ProgressView()
                .scaleEffect(0.8)
            }
          }
        }
        
        if let error = lastError {
          Text("Last Error: \(error)")
            .font(.caption)
            .foregroundColor(.red)
            .themedListRowBG(enablePadding: true)
        }
        
        if let success = lastSuccess {
          Text("Last Success: \(success)")
            .font(.caption)
            .foregroundColor(.green)
            .themedListRowBG(enablePadding: true)
        }
      }
      .themedListDividers()
      
      Section("Error Reporting") {
        WListButton {
          testErrorReporting()
        } label: {
          Label("Test Error Reporting", systemImage: "exclamationmark.triangle")
        }
        
        WListButton {
          clearDebugInfo()
        } label: {
          Label("Clear Debug Info", systemImage: "trash")
            .foregroundColor(.red)
        }
      }
      .themedListDividers()
      
      Section("API Information") {
        if let accessToken = RedditAPI.shared.loggedUser.accessToken {
          Text("Access Token: \(String(accessToken.prefix(20)))...")
            .font(.caption)
            .themedListRowBG(enablePadding: true)
        }
        
        if let refreshToken = RedditAPI.shared.loggedUser.refreshToken {
          Text("Refresh Token: \(String(refreshToken.prefix(20)))...")
            .font(.caption)
            .themedListRowBG(enablePadding: true)
        }
        
        if let expiration = RedditAPI.shared.loggedUser.expiration {
          Text("Token Expires In: \(expiration) seconds")
            .font(.caption)
            .themedListRowBG(enablePadding: true)
        }
        
        if let lastRefresh = RedditAPI.shared.loggedUser.lastRefresh {
          Text("Last Refresh: \(lastRefresh)")
            .font(.caption)
            .themedListRowBG(enablePadding: true)
        }
        
        Text("API Base URL: \(RedditAPI.redditApiURLBase)")
          .font(.caption)
          .themedListRowBG(enablePadding: true)
      }
      .themedListDividers()
    }
    .themedListBG(theme.lists.bg)
    .navigationTitle("Debug Tools")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  private func testFetchSubreddits() {
    isLoading = true
    lastError = nil
    lastSuccess = nil
    
    Task {
      let startTime = Date()
      let result = await RedditAPI.shared.fetchSubs()
      let endTime = Date()
      let duration = endTime.timeIntervalSince(startTime)
      
      await MainActor.run {
        isLoading = false
        if result != nil {
          lastSuccess = "Fetched subreddits in \(String(format: "%.2f", duration))s"
        } else {
          lastError = "Failed to fetch subreddits after \(String(format: "%.2f", duration))s"
        }
      }
    }
  }
  
  private func testErrorReporting() {
    let testError = """
    Test Error Report:
    - Timestamp: \(Date())
    - App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
    - Device: \(UIDevice.current.model)
    - iOS Version: \(UIDevice.current.systemVersion)
    - Test Message: This is a test error report to verify the error reporting system is working correctly.
    """
    Oops.shared.sendError(testError)
  }
  
  private func clearDebugInfo() {
    lastError = nil
    lastSuccess = nil
  }
}
