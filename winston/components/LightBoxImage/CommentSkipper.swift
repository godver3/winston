//
//  CommentSkipper.swift
//  OpenArtemis
//
//  Created by daniel on 12/8/23.
//

import SwiftUI
import Defaults

struct CommentSkipper: ViewModifier {
  @Environment(\.useTheme) private var selectedTheme
  @Binding var showJumpToNextCommentButton: Bool
  @Binding var topVisibleCommentId: String?
  @Binding var previousScrollTarget: String?
  @Default(.CommentLinkDefSettings) private var defSettings

  var comments: [Comment]
  var reader: ScrollViewProxy
  var refresh: () -> Void
    
  @Binding var commentsLoading: Bool
  
  func body(content: Content) -> some View {
    content.overlay {
      if showJumpToNextCommentButton {
        HStack {
          
          
          if selectedTheme.posts.inlineFloatingPill && !defSettings.jumpNextCommentButtonLeft{
            Spacer()
          }
          
          VStack {
            Spacer()
              
              HStack(spacing: 14) {
                  Image(systemName: "chevron.left")
                    .fontSize(18, .semibold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 14)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .drawingGroup()
                    .floating()
                    .scaleEffect(1)
                    .onTapGesture {
                        Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                        Nav.shared.activeRouter.goBack()
                    }
                  
                  Image(systemName: "arrow.clockwise")
                    .fontSize(18, .semibold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 14)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .drawingGroup()
                    .floating()
                    .scaleEffect(1)
                    .onTapGesture {
                        Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                        refresh()
                    }
                    .rotationEffect(Angle(degrees: commentsLoading ? -360 : 0), anchor: .center)
                  
                  Image(systemName: "chevron.down")
                    .fontSize(18, .semibold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 14)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .drawingGroup()
                    .floating()
                    .scaleEffect(1)
                    .onTapGesture {
                        Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                        withAnimation {
                          jumpToNextComment()
                        }
                    }
              }
          }
          .padding()
          
          if !selectedTheme.posts.inlineFloatingPill || defSettings.jumpNextCommentButtonLeft {
            Spacer()
          }
        }
      }
    }
  }
  
  private func jumpToNextComment() {
    if topVisibleCommentId == nil, let id = comments.first?.id {
      reader.scrollTo(id, anchor: .top)
      topVisibleCommentId = id
      return
    }
    
    if let topVisibleCommentId = topVisibleCommentId {
      let topVisibleCommentIndex = comments.map { $0.id }.firstIndex(of: topVisibleCommentId) ?? 0
      if topVisibleCommentId == previousScrollTarget {
        let nextIndex = min(topVisibleCommentIndex + 1, comments.count - 1)
        reader.scrollTo(comments[nextIndex].id, anchor: .top)
        previousScrollTarget = nextIndex < comments.count - 1 ? comments[nextIndex + 1].id : nil
      } else {
        let nextIndex = min(topVisibleCommentIndex + 1, comments.count - 1)
//        print(comments.count)
//        print(comments)
//        print("------------")
//        print(nextIndex)
        reader.scrollTo(comments[nextIndex].id, anchor: .top)
        previousScrollTarget = topVisibleCommentId
      }
    }
  }
}

extension View {
  func commentSkipper(
    showJumpToNextCommentButton: Binding<Bool>,
    topVisibleCommentId: Binding<String?>,
    previousScrollTarget: Binding<String?>,
    comments: [Comment],
    reader: ScrollViewProxy,
    refresh: @escaping () -> Void,
    commentsLoading: Binding<Bool>
  ) -> some View {
    modifier(
      CommentSkipper(
        showJumpToNextCommentButton: showJumpToNextCommentButton,
        topVisibleCommentId: topVisibleCommentId,
        previousScrollTarget: previousScrollTarget,
        comments: comments,
        reader: reader,
        refresh: refresh,
        commentsLoading: commentsLoading
      )
    )
  }
}
