//
//  FontSelector.swift
//  winston
//
//  Created by Igor Marcossi on 09/09/23.
//

import SwiftUI

struct FontSelector: View {
  @Binding var theme: ThemeText
  var defaultVal: ThemeText
  
  var body: some View {
    VStack {
      LabeledSlider(label: "Size", value: $theme.size, range: 6...32)
        .resetter($theme.size, defaultVal.size)
      
      Divider()
      
      HStack(spacing: 2) {
        ForEach(CodableFontWeight.allCases, id: \.self) { weight in
          Text("aA")
            .fontSize(20, weight.t)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RR(8, .primary.opacity(theme.weight == weight ? 0.1 : 0)))
            .onTapGesture {
              withAnimation(.default.speed(2)) {
                theme.weight = weight
              }
            }
        }
      }
      .frame(height: 48)
      .padding(.horizontal, 16)
      .resetter($theme.weight, defaultVal.weight)
      
      Divider()
      
      SchemesColorPicker(theme: $theme.color, defaultVal: defaultVal.color)
    }
  }
}
