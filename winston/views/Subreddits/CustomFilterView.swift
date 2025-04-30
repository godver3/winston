//
//  NewFilterView.swift
//  winston
//
//  Created by Zander Bobronnikov on 12/4/23.


import SwiftUI
import NukeUI
import CoreData
import Defaults

struct CustomFilterView: View {
  @Environment(\.useTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  
  @Default(.subredditFilters) var subredditFilters
  
  var filter: ShallowCachedFilter
  var subId: String
  
    @State var draftFilter = CachedFilter.getShallow(bgColor: "FFFFF", subID: "", text: "", label: "")
  
  func removeFromDefaults() {
    var subFilters = CachedFilter.filtersFromDefaultsString(subredditFilters[subId])
    subFilters.removeAll { other in filter == other }
    
    subredditFilters[subId] = CachedFilter.getDefaultsString(subFilters)
  }
  
  func saveToDefaults(last: Bool) {
    var subFilters = CachedFilter.filtersFromDefaultsString(subredditFilters[subId])
    subFilters.removeAll { other in filter == other }
    
    if last {
      subFilters.insert(draftFilter, at: 0)
    } else {
      subFilters.append(draftFilter)
    }
    
    subredditFilters[subId] = CachedFilter.getDefaultsString(subFilters)
  }
  
  
  var body: some View {
    let anyChanges = filter != draftFilter
    
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text(filter.new ? "New filter" : "Edit filter").fontSize(24, .semibold)
          
          VStack (alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
              
              BigInput(l: "Search text", t: Binding(get: { draftFilter.text }, set: { draftFilter = draftFilter.updateText($0) }), placeholder: "Filter text")
              
              BigColorPicker(title: "Color", initialValue: filter.bgColor ?? "FFFFFF", color:  Binding(get: { ThemeColor(hex: draftFilter.bgColor  ?? "FFFFFF") }, set: { draftFilter = draftFilter.updateBG($0.hex) }))
            }
            
            BigInput(l: "Label", t: Binding(get: { draftFilter.label }, set: { draftFilter = draftFilter.updateLabel($0) }), placeholder: "Custom label")
          }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
      }
      .themedListBG(.color(theme.lists.foreground.color))
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel", role: .destructive) {
            dismiss()
          }
        }
        
        if !filter.new {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Delete", role: .destructive) {
              removeFromDefaults()
              dismiss()
            }
            .foregroundColor(.red)
          }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
          Button("Back") {
            saveToDefaults(last: true)
            dismiss()
          }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
          Button("Front") {
            saveToDefaults(last: false)
            dismiss()
          }
        }
      }
      .onAppear {
        draftFilter = filter
      }
      .interactiveDismissDisabled(anyChanges)
    }
  }
}

struct BigColorPicker: View {
  var title: String
  var initialValue: String
  @Binding var color: ThemeColor
  var placeholder: String? = nil
    
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title.uppercased()).fontSize(12, .semibold).frame(minWidth: title.uppercased().width(font: UIFont.systemFont(ofSize: 12, weight: .semibold)), alignment: .leading).padding(.leading, 12).opacity(0.5)
      
      VStack (alignment: .leading) {
        ThemeColorPicker("", $color)
          .overlay(
            Color.clear
              .frame(maxWidth: .infinity)
              .resetter($color, ThemeColor(hex: initialValue))
              .padding(.trailing, 44)
          ).labelsHidden()
      }
      .padding(.vertical, 14)
      .padding(.horizontal, 14)
      .frame(minWidth: title.uppercased().width(font: UIFont.systemFont(ofSize: 12, weight: .semibold)) + 40)
      .background(RR(16, Color("acceptableBlack")))
    }
  }
}
