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
  var openUnseenSkipper: (ScrollViewProxy) -> Void
  var updateTopCommentIdx: (String) -> Void
  @Binding var searchOpen: Bool
  @Binding var unseenSkipperOpen: Bool
    
  @State private var refreshRotationDegrees = 0.0
  @State private var pressingDown: Bool = false
  @State private var longPressed: Bool = false
  @State private var longPressTimer: Timer? = nil
      
  private let buttonSize: CGFloat = 48
  private let longPressDuration: Double = 0.275
    
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
                    .fontSize(22, .semibold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 14)
                    .frame(width: buttonSize, height: buttonSize)
                    .clipShape(Circle())
                    .drawingGroup()
                    .floating()
                    .onTapGesture {
                        Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                        Nav.shared.activeRouter.goBack()
                    }
                  
                  Image(systemName: "arrow.clockwise")
                    .fontSize(22, .semibold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 14)
                    .frame(width: buttonSize, height: buttonSize)
                    .clipShape(Circle())
                    .drawingGroup()
                    .floating()
                    .onTapGesture {
                        Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                        refresh()
                        
                        withAnimation {
                            refreshRotationDegrees += 360
                        }
                    }
                    .rotationEffect(Angle(degrees: refreshRotationDegrees), anchor: .center)
                  
                  Image(systemName: "chevron.down")
                    .fontSize(22, .semibold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 14)
                    .frame(width: buttonSize, height: buttonSize)
                    .clipShape(Circle())
                    .drawingGroup()
                    .floating()
                    .scaleEffect(pressingDown ? 0.95 : 1)
                    .animation(.bouncy(duration: 0.3, extraBounce: 0.225), value: pressingDown)
                    .onTapGesture {
                      if longPressed {
                        longPressed = false
                        return
                      }
                     
                      Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                      withAnimation {
                        jumpToNextComment()
                      }
                    }
                    .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 10, perform: {}, onPressingChanged: { val in
                      pressingDown = val
                      
                      if val {
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDuration, repeats: false) { _ in
                          Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                          longPressed = true
                          
                          DispatchQueue.main.async {
                            withAnimation {
                              openUnseenSkipper(reader)
                            }
                          }
                        }
                      } else {
                        longPressTimer?.invalidate()
                      }
                    })
              }
          }
          .padding()
          .opacity(searchOpen || unseenSkipperOpen ? 0 : 1)
          .animation(.linear(duration: 0.1), value: searchOpen || unseenSkipperOpen)
          
          if !selectedTheme.posts.inlineFloatingPill || defSettings.jumpNextCommentButtonLeft {
            Spacer()
          }
        }
      }
    }
  }
  
  private func jumpToNextComment() {
    if topVisibleCommentId == nil, let id = comments.first?.id {
      updateTopCommentIdx(id)
      reader.scrollTo(id, anchor: .top)
      topVisibleCommentId = id
      return
    }
    
    if let topVisibleCommentId = topVisibleCommentId {
      let topCommentIdx = comments.map { $0.id }.firstIndex(of: topVisibleCommentId) ?? 0
      if topVisibleCommentId == previousScrollTarget {
        let nextIndex = min(topCommentIdx + 1, comments.count - 1)
        updateTopCommentIdx(comments[nextIndex].id)
        reader.scrollTo(comments[nextIndex].id, anchor: .top)
        previousScrollTarget = nextIndex < comments.count - 1 ? comments[nextIndex + 1].id : nil
      } else {
        let nextIndex = min(topCommentIdx + 1, comments.count - 1)
//        print(comments.count)
//        print(comments)
//        print("------------")
//        print(nextIndex)
        updateTopCommentIdx(comments[nextIndex].id)
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
    openUnseenSkipper: @escaping (ScrollViewProxy) -> Void,
    updateTopCommentIdx: @escaping (String) -> Void,
    searchOpen: Binding<Bool>,
    unseenSkipperOpen: Binding<Bool>
  ) -> some View {
    modifier(
      CommentSkipper(
        showJumpToNextCommentButton: showJumpToNextCommentButton,
        topVisibleCommentId: topVisibleCommentId,
        previousScrollTarget: previousScrollTarget,
        comments: comments,
        reader: reader,
        refresh: refresh,
        openUnseenSkipper : openUnseenSkipper,
        updateTopCommentIdx : updateTopCommentIdx,
        searchOpen: searchOpen,
        unseenSkipperOpen: unseenSkipperOpen
      )
    )
  }
}
