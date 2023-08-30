//
//  URLImage.swift
//  winston
//
//  Created by Igor Marcossi on 19/08/23.
//

import SwiftUI
import NukeUI
import Nuke
import NukeExtensions
import Giffy

struct URLImage: View {
  let url: URL
  var processors: [ImageProcessing]? = nil
  var body: some View {
    if url.absoluteString.hasSuffix(".gif") {
      AsyncGiffy(url: url) { phase in
          switch phase {
          case .loading:
              ProgressView()
          case .error:
              Text("Failed to load GIF")
          case .success(let giffy):
            giffy.scaledToFit()
          }
      }
    } else {
      LazyImage(url: url, transaction: Transaction(animation: .default)) { state in
        if let image = state.image {
          image.resizable()
        } else if state.error != nil {
          Color.red.opacity(0.1)
            .overlay(Image(systemName: "xmark.circle.fill").foregroundColor(.red))
        } else {
          ProgressView()
        }
      }
      .processors(processors)
    }
  }
}
