import SwiftUI

struct EditReviewView: View {
    let review: Review
    let restaurant: Restaurant
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var stars: Int
    @State private var comment: String
    @State private var imageData: Data? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var existingImageURL: String?
    @State private var shouldRemoveImage: Bool = false
    
    @State private var isSaving = false
    @State private var showValidation = false
    @State private var error: String? = nil
    @State private var showPicker = false
    @State private var uploadProgress: Double = 0.0
    @State private var showSuccessMessage = false
    
    private let repo = ReviewsRepository()
    
    init(review: Review, restaurant: Restaurant) {
        self.review = review
        self.restaurant = restaurant
        _stars = State(initialValue: review.stars)
        _comment = State(initialValue: review.comment)
        _existingImageURL = State(initialValue: review.imageURL)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                Text("Edit review for")
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
                    } else if let existingURL = existingImageURL, !existingURL.isEmpty {
                        RemoteImage(urlString: existingURL)
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
                            Text("Change photo")
                                .font(.custom("Montserrat-SemiBold", size: 16))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(PrimaryCapsuleButton(color: Palette.orange))
                        
                        if existingImageURL != nil || capturedImage != nil {
                            Button {
                                imageData = nil
                                capturedImage = nil
                                existingImageURL = nil
                                shouldRemoveImage = true
                            } label: {
                                Text("Remove")
                                    .font(.custom("Montserrat-SemiBold", size: 16))
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(PrimaryCapsuleButton(color: .red))
                        }
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
                
                if showSuccessMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Review updated successfully!")
                            .font(.custom("Montserrat-SemiBold", size: 14))
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Button {
                    Task { await submit() }
                } label: {
                    let pct = Int((uploadProgress * 100).rounded())
                    Text(isSaving && uploadProgress > 0 ? "Uploading \(pct)%" : (isSaving ? "Saving…" : "Save changes"))
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
        .navigationTitle("Edit Review")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            CamaraPicker(imageData: $imageData)
                .onDisappear {
                    if let data = imageData, let ui = UIImage(data: data) {
                        capturedImage = ui
                        existingImageURL = nil // Clear existing URL when new image is selected
                        shouldRemoveImage = false // Reset remove flag when new image is selected
                    }
                }
        }
        .task {
            // Load existing image locally if available
            if let localPath = review.imageLocalPath,
               FileManager.default.fileExists(atPath: localPath),
               let data = try? Data(contentsOf: URL(fileURLWithPath: localPath)),
               let ui = UIImage(data: data) {
                await MainActor.run {
                    capturedImage = ui
                }
            }
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
            // Only send imageData if a new image was selected
            let imageToUpload = capturedImage != nil && imageData != nil ? imageData : nil
            try await repo.updateReview(
                reviewId: review.id,
                stars: stars,
                comment: trimmed,
                imageData: imageToUpload,
                removeImage: shouldRemoveImage,
                progress: { pct in
                    Task { @MainActor in
                        self.uploadProgress = pct
                    }
                }
            )
            await MainActor.run {
                isSaving = false
                uploadProgress = 1
                // Show success message - the notification from repository will trigger refresh
                showSuccessMessage = true
                
                // Dismiss after showing success message for 1.5 seconds to allow refresh
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isSaving = false
                uploadProgress = 0
            }
        }
    }
}

