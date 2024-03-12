//
//  SwiftUIView.swift
//  winston
//
//  Created by Igor Marcossi on 11/07/23.
//

import SwiftUI

struct UserLinkContainer: View {
  var noHPad = false
  @State var user: User
  var body: some View {
    UserLink(noHPad: noHPad, user: user)
  }
}

struct UserLink: View {
  var noHPad = false
  var user: User
    var body: some View {
      if let data = user.data {
        HStack(spacing: 12) {
          if let icon = data.icon_img {
            AvatarView(saved: false, url: icon, userID: data.name, avatarSize: 64)
          }
          
          VStack(alignment: .leading) {
            Text("u/\(data.name)")
              .fontSize(18, .semibold)
            Text("\(formatBigNumber(data.total_karma ?? ((data.link_karma ?? 0) + (data.comment_karma ?? 0)))) karma")
              .fontSize(14).opacity(0.5)
            if let description = data.subreddit?.public_description {
              Text((description).md()).lineLimit(2)
                .fontSize(15).opacity(0.75)
            }
          }
        }
        .padding(.horizontal, noHPad ? 0 : 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedListRowLikeBG()
        .mask(RR(20, .black))
        .onTapGesture {
          Nav.to(.reddit(.user(user)))
        }
      }
    }
}
