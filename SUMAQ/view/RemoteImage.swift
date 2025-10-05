// RemoteImage.swift
// SUMAQ

import SwiftUI

struct RemoteImage: View {
    let urlString: String
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = 12

    @State private var uiImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle().fill(Color(.secondarySystemBackground))
                    .overlay(Image(systemName: "photo").opacity(0.4))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: urlString) { await load() }
    }

    private func load() async {
        guard uiImage == nil, !urlString.isEmpty else { return }
        if let cached = ImageCache.shared.image(forKey: urlString) {
            uiImage = cached; return
        }
        isLoading = true
        defer { isLoading = false }

        if urlString.hasPrefix("data:image") {
            if let comma = urlString.firstIndex(of: ",") {
                let b64 = String(urlString[urlString.index(after: comma)...])
                if let data = Data(base64Encoded: b64, options: [.ignoreUnknownCharacters]),
                   let img = ImageCache.shared.downsampled(from: data) {
                    ImageCache.shared.set(img, forKey: urlString)
                    uiImage = img
                }
            }
            return
        }

        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = ImageCache.shared.downsampled(from: data) {
                ImageCache.shared.set(img, forKey: urlString)
                uiImage = img
            }
        } catch {
        }
    }
}
