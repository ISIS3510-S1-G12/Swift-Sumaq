import SwiftUI

struct AddReviewView: View {
    let restaurant: Restaurant

    @Environment(\.dismiss) private var dismiss

    @State private var stars: Int = 5
    @State private var comment: String = ""
    @State private var imageData: Data? = nil
    @State private var capturedImage: UIImage? = nil

    @State private var isSaving = false
    @State private var showValidation = false
    @State private var error: String? = nil
    @State private var showPicker = false

    private let repo = ReviewsRepository()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("Write a review for")
                    .font(.custom("Montserrat-Regular", size: 14))
                    .foregroundColor(.secondary)

                Text(restaurant.name)
                    .font(.custom("Montserrat-SemiBold", size: 22))
                    .foregroundColor(Palette.burgundy)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Rating")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= stars ? "star.fill" : "star")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .foregroundColor(index <= stars ? Palette.purpleLight : .gray)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        stars = index
                                    }
                                }
                        }
                    }
                    .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Comment")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(.primary)

                    ZStack(alignment: .topLeading) {
                        if comment.isEmpty {
                            Text("Write your thoughts…")
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        TextEditor(text: $comment)
                            .font(.custom("Montserrat-Regular", size: 16))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    .background(Palette.grayLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Photo (optional)")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                    if let img = capturedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Palette.grayLight)
                            .frame(height: 140)
                            .overlay(
                                Text("No image selected")
                                    .foregroundColor(.secondary)
                            )
                    }

                    HStack {
                        Button {
                            showPicker = true
                        } label: {
                            Text("Add photo")
                                .font(.custom("Montserrat-SemiBold", size: 16))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(PrimaryCapsuleButton(color: Palette.orange))
                    }
                }

                if showValidation {
                    Text("Please write a comment before submitting.")
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    let pct = Int((uploadProgress * 100).rounded())
                    Text(isSaving && uploadProgress > 0 ? "Uploading \(pct)%" : (isSaving ? "Submitting…" : "Submit review"))
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(PrimaryCapsuleButton(color: Palette.burgundy))
                .disabled(isSaving)

                if isSaving && uploadProgress > 0 && uploadProgress < 1 {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(.linear)
                        .tint(Palette.burgundy)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("New Review")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            CamaraPicker(imageData: $imageData)
                .onDisappear {
                    if let data = imageData, let ui = UIImage(data: data) {
                        capturedImage = ui
                    }
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reviewDidCreate)) { _ in
            dismiss()
        }
    }

    private func submit() async {
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showValidation = true
            return
        }
        isSaving = true
        error = nil
        do {
            uploadProgress = 0
            try await repo.createReview(
                restaurantId: restaurant.id,
                stars: stars,
                comment: trimmed,
                imageData: imageData,
                progress: { pct in
                    DispatchQueue.main.async {
                        self.uploadProgress = pct
                    }
                }
            )
            isSaving = false
            uploadProgress = 1
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            uploadProgress = 0
        }
    }
}
