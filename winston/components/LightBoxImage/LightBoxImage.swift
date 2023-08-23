//
//  LightBox.swift
//  winston
//
//  Created by Igor Marcossi on 28/06/23.
//

import SwiftUI
import CoreMedia

private let SPACING = 24.0

struct LightBoxImage: View {
  @ObservedObject var post: Post
  var i: Int
  var imagesArr: [MediaExtracted]
  var namespace: Namespace.ID
  @Environment(\.dismiss) private var dismiss
  @State private var appearBlack = false
  @State private var appearContent = false
  @State private var drag: CGSize = .zero
  @State private var xPos: CGFloat = 0
  @State private var dragAxis: Axis?
  @State private var activeIndex = 0
  @State private var loading = false
  @State private var done = false
  @State private var showOverlay = true
  
  @State private var isPinching: Bool = false
  @State private var scale: CGFloat = 1.0
  
  private enum Axis {
    case horizontal
    case vertical
  }
  
  func toggleOverlay() {
    withAnimation(.easeOut(duration: 0.2)) {
      showOverlay.toggle()
    }
  }
  
  var body: some View {
    let interpolate = interpolatorBuilder([0, 100], value: abs(drag.height))
    HStack(spacing: SPACING) {
      ForEach(Array(imagesArr.enumerated()), id: \.element.id) { i, img in
        let selected = i == activeIndex
        LightBoxElementView(el: img, onTap: toggleOverlay, isPinching: $isPinching)
          .allowsHitTesting(selected)
          .scaleEffect(!selected ? 1 : interpolate([1, 0.9], true))
          .blur(radius: selected && loading ? 24 : 0)
          .offset(x: !selected ? 0 : dragAxis == .vertical ? drag.width : 0, y: i != activeIndex ? 0 : dragAxis == .vertical ? drag.height : 0)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
    .offset(x: xPos + (dragAxis == .horizontal ? drag.width : 0))
    .frame(maxWidth: UIScreen.screenWidth, maxHeight: UIScreen.screenHeight, alignment: .leading)
    .highPriorityGesture(
      scale > 1
      ? nil
      : DragGesture(minimumDistance: 20)
        .onChanged { val in
          if dragAxis == nil {
            if abs(val.predictedEndTranslation.width) > abs(val.predictedEndTranslation.height) {
              dragAxis = .horizontal
            } else if abs(val.predictedEndTranslation.width) < abs(val.predictedEndTranslation.height) {
              dragAxis = .vertical
            }
          }
          
          if dragAxis != nil {
            var transaction = Transaction()
            transaction.isContinuous = true
            transaction.animation = .interpolatingSpring(stiffness: 1000, damping: 100, initialVelocity: 0)
            
            var endPos = val.translation
            if dragAxis == .horizontal {
              endPos.height = 0
            }
            withTransaction(transaction) {
              drag = endPos
            }
          }
        }
        .onEnded { val in
          if dragAxis == .horizontal {
            let predictedEnd = val.predictedEndTranslation.width
            drag = .zero
            xPos += val.translation.width
            let newActiveIndex = min(imagesArr.count - 1, max(0, activeIndex + (predictedEnd < -(UIScreen.screenWidth / 2) ? 1 : predictedEnd > UIScreen.screenWidth / 2 ? -1 : 0)))
            let finalXPos = -(CGFloat(newActiveIndex) * (UIScreen.screenWidth + (SPACING)))
            let distance = abs(finalXPos - xPos)
            activeIndex = newActiveIndex
            var initialVel = abs(predictedEnd / distance)
            initialVel = initialVel < 3.75 ? 0 : initialVel * 2
            withAnimation(.interpolatingSpring(stiffness: 150, damping: 17, initialVelocity: initialVel)) {
              xPos = finalXPos
              dragAxis = nil
            }
          } else {
            let shouldClose = abs(val.translation.width) > 100 || abs(val.translation.height) > 100
            
            if shouldClose {
              withAnimation(.easeOut) {
                appearBlack = false
              }
            }
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 20, initialVelocity: 0)) {
              drag = .zero
              dragAxis = nil
              if shouldClose {
                dismiss()
              }
            }
          }
        }
    )
    .overlay(LightBoxOverlay(post: post, opacity: !showOverlay || isPinching ? 0 : interpolate([1, 0], false), imagesArr: imagesArr, activeIndex: activeIndex, loading: $loading, done: $done))
    .background(
      !appearBlack
      ? nil
      : Color.black
        .opacity(interpolate([1, 0], false))
        .onTapGesture {
          withAnimation(.easeOut) {
            appearBlack = false
          }
        }
        .allowsHitTesting(appearBlack)
        .transition(.opacity)
    )
    .overlay(
      !loading && !done
      ? nil
      : ZStack {
        if done {
          Image(systemName: "checkmark.circle.fill")
            .fontSize(40)
            .transition(.scaleAndBlur)
        } else {
          ProgressView()
            .transition(.scaleAndBlur)
        }
      }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.25))
    )
    .ignoresSafeArea(edges: .all)
    .compositingGroup()
    .opacity(appearContent ? 1 : 0)
    .onChange(of: done) { val in
      if val {
        doThisAfter(0.5) {
          withAnimation(spring) {
            done = false
            loading = false
          }
        }
      }
    }
    .onAppear {
      xPos = -CGFloat(i) * (UIScreen.screenWidth + SPACING)
      activeIndex = i
      withAnimation(.easeOut) {
        appearContent = true
        appearBlack = true
      }
    }
    .transition(.opacity)
  }
}


