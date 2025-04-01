//
//  FloatingFeedMenu.swift
//  winston
//
//  Created by Igor Marcossi on 16/12/23.
//

import SwiftUI
import Combine
import Defaults

struct FloatingFeedMenu: View, Equatable {
  static func == (lhs: FloatingFeedMenu, rhs: FloatingFeedMenu) -> Bool {
    lhs.subId == rhs.subId && lhs.filters == rhs.filters && lhs.selectedFilter == rhs.selectedFilter
  }
  
  @Default(.subredditFilters) var subredditFilters
  
  var subId: String
  var filters: [ShallowCachedFilter]
  @Binding var selectedFilter: ShallowCachedFilter?
  @Binding var customFilter: ShallowCachedFilter?
  
  @State private var menuOpen = false
  @State private var showingFilters = false
  @State private var compact: Bool
  
  @Namespace private var ns
  
  private let mainTriggerSize: Double = 64
  private let actionsSize: Double = 48
  private let itemsSpacing: Double = 20
  private let screenEdgeMargin: Double = 12
  
  var itemsSpacingDownscaled: Double { itemsSpacing - ((mainTriggerSize - actionsSize) / 2) }
  
  @Default(.SubredditFeedDefSettings) var subredditFeedDefSettings
  @Default(.PostLinkDefSettings) var postLinkDefSettings
  
  init(subId: String, filters: [ShallowCachedFilter], selectedFilter: Binding<ShallowCachedFilter?>, customFilter: Binding<ShallowCachedFilter?>) {
    self.subId = subId
    self.filters = filters
    
    self._selectedFilter = selectedFilter
    self._customFilter = customFilter
    
    _compact = State(initialValue: Defaults[.SubredditFeedDefSettings].compactPerSubreddit[subId] ?? Defaults[.PostLinkDefSettings].compactMode.enabled)
  }
  
  func dismiss() {
    if menuOpen {
      Hap.shared.play(intensity: 0.75, sharpness: 0.4)
      //      doThisAfter(0) {
      withAnimation {
        showingFilters = false
      }
      withAnimation(.snappy(extraBounce: 0.3)) {
        menuOpen = false
      }
      
    }
  }
  
  func selectFilter(_ filter: ShallowCachedFilter) {
    let newVal = selectedFilter == filter ? nil : filter
    withAnimation(.spring) {
      selectedFilter = newVal
    }
  }
  
  var body: some View {
    let customFilters = CachedFilter.filtersFromDefaultsString(subredditFilters[subId])

    ZStack(alignment: .bottomTrailing) {
      FloatingBGBlur(active: menuOpen, dismiss: dismiss).equatable()
      
      HStack(alignment: .bottom, spacing: 0) {
        Spacer()
        ZStack(alignment: .bottomTrailing) {
          if !showingFilters, let selectedFilter {
            FilterButton(filter: selectedFilter, isSelected: true, selectFilter: selectFilter, customFilter: $customFilter)
              .matchedGeometryEffect(id: "floating-\(selectedFilter.id)", in: ns, properties: .position)
              .padding(.trailing, itemsSpacingDownscaled)
              .frame(height: mainTriggerSize)
              .padding(.bottom, screenEdgeMargin)
              .transition(.offset(x: 0.01))
          }
          
          if menuOpen {
            HStack(spacing: 8) {
              ForEach(Array(customFilters.enumerated()).reversed(), id: \.element) { i, el in
                let isSelected = selectedFilter?.id == el.id
                let placeholder = isSelected && !showingFilters
                let elId = "floating-\(el.id)\(placeholder ? "-placeholder" : "")"
                
                FilterButton(filter: el, isSelected: isSelected, selectFilter: selectFilter, customFilter: $customFilter)
                //                    .equatable()
                  .matchedGeometryEffect(id: "floating-\(el.id)", in: ns)
                  .scaleEffect(showingFilters || isSelected ? 1 : 0.01, anchor: .trailing)
                  .opacity((showingFilters || isSelected) && !placeholder ? 1 : 0)
                  .animation(.bouncy.delay(Double(showingFilters && !isSelected ? i : 0) * 0.125), value: showingFilters)
                  .transition(.offset(x: 0.01))
                  .id(elId)
              }
            }
            .padding(.trailing, 12)
            .frame(height: mainTriggerSize, alignment: .trailing)
            .padding(.top, 16)
            .contentShape(Rectangle())
            .scrollClipDisabled()
            .padding(.bottom, screenEdgeMargin)
            .transition(.offset(x: 0.01))
          }
        
          let showBackButton = (!menuOpen || customFilters.count == 0) && selectedFilter == nil
          HStack(spacing: 14) {
                Image(systemName: "chevron.left")
                  .fontSize(showBackButton ? 22 : 0, .semibold)
                  .foregroundStyle(Color.accentColor)
                  .padding(.horizontal, 14)
                  .frame(width: showBackButton ? actionsSize : 0, height: showBackButton ? actionsSize : 0)
                  .clipShape(Circle())
                  .drawingGroup()
                  .floating()
                  .animation(.bouncy.delay(0), value: showBackButton)
                  .increaseHitboxOf(actionsSize, by: 1.125, shape: Circle(), disable: !showBackButton)
                  .onTapGesture {
                      Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                      Nav.shared.activeRouter.goBack()
                  }
            }
            .padding(.trailing, 12)
            .frame(height: mainTriggerSize, alignment: .trailing)
            .padding(.top, 16)
            .contentShape(Rectangle())
            .scrollClipDisabled()
            .padding(.bottom, screenEdgeMargin)
        }
        
        // -
        
        VStack(spacing: itemsSpacingDownscaled) {
          VStack(spacing: itemsSpacing) {
            if menuOpen {
              Image(systemName: "star.fill")
                .fontSize(22, .bold)
                .frame(width: actionsSize, height: actionsSize)
                .foregroundStyle(Color.accentColor)
                .floating()
                .transition(.comeFrom(.bottom, index: 1, total: 2))
              
              Image(systemName: compact ? "doc.text.image" : "doc.plaintext")
                .fontSize(22, .bold)
                .frame(width: actionsSize, height: actionsSize)
                .foregroundColor(Color.accentColor)
                .floating()
                .transition(.comeFrom(.bottom, index: 0, total: 2))
                .increaseHitboxOf(actionsSize, by: 1.125, shape: Circle(), disable: menuOpen)
                .highPriorityGesture(TapGesture().onEnded({
                  Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                  compact = !compact
                  subredditFeedDefSettings.compactPerSubreddit[self.subId] = compact
                }))
              
              Image(systemName: "plus")
                .fontSize(22, .bold)
                .frame(width: actionsSize, height: actionsSize)
                .foregroundColor(Color.accentColor)
                .floating()
                .transition(.comeFrom(.bottom, index: 0, total: 2))
                .increaseHitboxOf(actionsSize, by: 1.125, shape: Circle(), disable: menuOpen)
                .highPriorityGesture(TapGesture().onEnded({
                  Hap.shared.play(intensity: 0.75, sharpness: 0.9)
                  customFilter = CachedFilter.getNewShallow(subredditId: subId)
                }))
            }
          }
          
          FloatingMainTrigger(menuOpen: $menuOpen, showingFilters: $showingFilters, dismiss: dismiss, size: mainTriggerSize, actionsSize: actionsSize)
        }
        .padding([.trailing, .bottom], screenEdgeMargin)
      }
    }
  }
}



extension View {
  func floatingMenu(subId: String?, filters: [ShallowCachedFilter], selectedFilter: Binding<ShallowCachedFilter?>, customFilter: Binding<ShallowCachedFilter?>) -> some View {
    self.overlay(alignment: .bottomTrailing) {
        if let subId {
            FloatingFeedMenu(subId: subId, filters: filters, selectedFilter: selectedFilter, customFilter: customFilter)
        }
      }
  }
}

func createTimer(seconds: Double, callback: @escaping (Int, Int) -> Void) -> Timer {
  let totalLoops = Int(120.0 * seconds)
  var currentLoop = 0
  
  let timer = Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { (timer) in
    callback(currentLoop, totalLoops)
    currentLoop += 1
    if currentLoop >= totalLoops {
      timer.invalidate()
    }
  }
  RunLoop.current.add(timer, forMode: .common)
  
  return timer
}
