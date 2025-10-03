//
//  RestaurantTopBar.swift
//  SUMAQ
//

import SwiftUI

struct RestaurantTopBar: View {
    let name: String
    let imageURL: String?
    var onAvatarTap: (() -> Void)? = nil

    private let lineColor: Color = Palette.burgundy
    private let lineHeight: CGFloat = 1
    private let sidePadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image("AppLogoUI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                HStack(spacing: 8) {
                    Text(name.isEmpty ? "My restaurant" : name)
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(Palette.burgundy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Button {
                        onAvatarTap?()
                    } label: {
                        Group {
                            if let url = imageURL, !url.isEmpty {
                                RemoteImage(urlString: url)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "building.2.crop.circle.fill")
                                    .resizable()
                                    .scaledToFill()
                            }
                        }
                        .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, sidePadding)

            Rectangle()
                .fill(lineColor)
                .frame(height: lineHeight)
                .padding(.horizontal, sidePadding)
        }
    }
}
