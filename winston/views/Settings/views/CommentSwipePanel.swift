//
//  CommentSwipePanel.swift
//  winston
//
//  Created by Igor Marcossi on 11/08/23.
//

import SwiftUI
import Defaults

struct CommentSwipePanel: View {
  @Default(.commentSwipeActions) private var commentSwipeActions
  
    var body: some View {
      List {
        
        Picker(selection: $commentSwipeActions.leftFirst) {
          ForEach(allCommentSwipeActions) { act in
            Label(act.label, systemImage: act.icon.normal)
              .tag(act)
          }
        } label: {
          Label("Drag Left", image: "dragLeft")
        }
        
        Picker(selection: $commentSwipeActions.rightFirst) {
          ForEach(allCommentSwipeActions) { act in
            Label(act.label, systemImage: act.icon.normal)
              .tag(act)
          }
        } label: {
          Label("Drag Right", image: "dragRight")
        }
        
        Picker(selection: $commentSwipeActions.leftSecond) {
          ForEach(allCommentSwipeActions) { act in
            Label(act.label, systemImage: act.icon.normal)
              .tag(act)
          }
        } label: {
          Label("Long Drag Left", image: "longDragLeft")
        }
        
        Picker(selection: $commentSwipeActions.rightSecond) {
          ForEach(allCommentSwipeActions) { act in
            Label(act.label, systemImage: act.icon.normal)
              .tag(act)
          }
        } label: {
          Label("Long Drag Right", image: "longDragRight")
        }
        
      }
      .navigationTitle("Comments Swipe Settings")
      .navigationBarTitleDisplayMode(.inline)
    }
}
