// ReviewCard.swift
// SUMAQ

import SwiftUI
import UIKit

struct ReviewCard: View {
    let author: String
    let restaurant: String
    let rating: Int
    let comment: String
    var avatarURL: String = ""
    
    var reviewImageURL: String? = nil
    var reviewLocalPath: String? = nil
    var isEditable: Bool = false
    var onEdit: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            avatarView
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(author)
                        .font(.custom("Montserrat-SemiBold", size: 15))
                        .foregroundColor(Palette.burgundy)
                    Spacer(minLength: 8)
                    StarsRow(rating: rating)
                    if isEditable {
                        Button(action: {
                            onEdit?()
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Palette.burgundy)
                                .frame(width: 36, height: 36)
                                .background(Palette.burgundy.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Text(restaurant)
                    .font(.custom("Montserrat-SemiBold", size: 14))
                    .foregroundColor(.primary)

                reviewPhotoSection

                Text(comment)
                    .font(.custom("Montserrat-Regular", size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        let trimmed = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(Palette.burgundy.opacity(0.85))
        } else if trimmed.hasPrefix("http") || trimmed.hasPrefix("data:image") {
            RemoteImage(urlString: trimmed).scaledToFill()
        } else {
            Image(trimmed).resizable().scaledToFill()
        }
    }


    @ViewBuilder
    private var reviewPhotoSection: some View {
        // Prioritize local path for offline access (simple file storage)
        if let path = reviewLocalPath, !path.isEmpty, FileManager.default.fileExists(atPath: path), let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .clipped()
                .padding(.vertical, 6)
        } else if let url = reviewImageURL, !url.isEmpty {
            RemoteImage(urlString: url)
                .scaledToFill()
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .clipped()
                .padding(.vertical, 6)
        }
    }
}
