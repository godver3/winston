//
//  AboutPanel.swift
//  winston
//
//  Created by Igor Marcossi on 01/08/23.
//

import SwiftUI

struct AboutPanel: View {
  let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
  let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
  @Environment(\.openURL) private var openURL
  @Environment(\.useTheme) private var theme
  var body: some View {
      List {
        Section {
          HStack {
            Image("winstonNoBG")
              .resizable()
              .scaledToFit()
              .frame(width: 48, height: 48)

            VStack(alignment: .leading) {
              Text("Winston")
                .fontSize(20, .bold)
              HStack{
                Text("Beta v" + (appVersion ?? "-1") + " Build \(build ?? "-1")")
              }
            }
          }
          .themedListRowBG(enablePadding: true)
          Text("Winston is developed by the lo.cafe team, a group of friends making amazing software together.")
            .themedListRowBG(enablePadding: true)
          WListButton {
            openURL(URL(string: "https://lo.cafe")!)
          } label: {
            Label("Visit lo.cafe Website", systemImage: "cup.and.saucer.fill")
          }
          WListButton {
            openURL(URL(string: "https://discord.gg/Jw3Syb3nrz")!)
          } label: {
            Label("Join the Discord Server", systemImage: "person.3.fill")
          }
          WListButton {
            openURL(URL(string: "https://patreon.com/user?u=93745105")!)
          } label: {
            Label("Support our Work!", systemImage: "heart.fill")
          }
        }
        .themedListDividers()
        
        Section {
          Text("Winston is a free and open source software, therefore it isn't against Reddit's policies.")
            .themedListRowBG(enablePadding: true)
          WListButton {
            openURL(URL(string: "https://github.com/Kinark/winston")!)
          } label: {
            Label("Check out Winston's Source Code", systemImage: "arrow.branch")
          }
        }
        .themedListDividers()
      }
      .themedListBG(theme.lists.bg)
      .navigationTitle("About")
      .navigationBarTitleDisplayMode(.inline)
    }
}

//struct AboutPanel_Previews: PreviewProvider {
//    static var previews: some View {
//        AboutPanel()
//    }
//}
