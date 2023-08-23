//
//  PostSwipePanel.swift
//  winston
//
//  Created by Igor Marcossi on 11/08/23.
//

import SwiftUI
import Defaults

struct PostSwipePanel: View {
  @Default(.postSwipeActions) private var postSwipeActions
  
    var body: some View {
      List {
        
        Picker(selection: $postSwipeActions.leftFirst) {
          ForEach(allPostSwipeActions) { act in
            Label(act.label, systemImage: act.icon.normal)
              .tag(act)
          }
        } label: {
          Label("Drag Left", image: "dragLeft")
        }
        
        Picker(selection: $postSwipeActions.rightFirst) {
          ForEach(allPostSwipeActions) { act in
            Label(act.label, systemImage: act.icon.normal)
              .tag(act)
          }
        } label: {
          Label("Drag Right", image: "dragRight")
        }
        
        Picker(selection: $postSwipeActions.leftSecond) {
          ForEach(allPostSwipeActions) { act in
            Label(act.label, systemImage: act.icon.normal)
              .tag(act)
          }
        } label: {
          Label("Long Drag Left", image: "longDragLeft")
        }
        
        Picker(selection: $postSwipeActions.rightSecond) {
          ForEach(allPostSwipeActions) { act in
            Label(act.label, systemImage: act.icon.normal)
              .tag(act)
          }
        } label: {
          Label("Long Drag Right", image: "longDragRight")
        }
        
      }
      .navigationTitle("Posts Swipe Settings")
      .navigationBarTitleDisplayMode(.inline)
    }
}
