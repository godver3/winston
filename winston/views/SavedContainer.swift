//
//  SavedContainer.swift
//  winston
//
//  Created by Zander Bobronnikov on 4/9/25.
//

//
//  SubredditsStack.swift
//  winston
//
//  Created by Igor Marcossi on 19/09/23.
//

import SwiftUI
import Defaults

struct SavedContainer: View {
  @State var router: Router
  @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
  @State private var sidebarSize: CGSize = .zero
  
  init(router: Router) {
    self._router = .init(initialValue: router)
  }
  
  var postContentWidth: CGFloat { .screenW - (!IPAD || columnVisibility == .detailOnly ? 0 : sidebarSize.width) }
  
  var body: some View {
      NavigationStack(path: $router.path) {
        Group {
            SubredditPosts(subreddit: Subreddit(id: savedKeyword))
              .id("\(savedKeyword)-sub-first-tab")
              .attachViewControllerToRouter(tabID: .saved)
        }
        .injectInTabDestinations()
      }
      .environment(\.contentWidth, postContentWidth)
  }
}
