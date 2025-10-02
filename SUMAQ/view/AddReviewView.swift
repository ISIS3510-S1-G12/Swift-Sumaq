// AddReviewView.swift
// SUMAQ

import SwiftUI

struct AddReviewView: View {
    let restaurant: Restaurant

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = ReviewsController()

    @State private var stars: Int = 5
    @State private var comment: String = ""

    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var imageData: Data?

    @State private var showValidation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header 
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Palette.burgundy)
                    }
                    Text("New review")
                        .font(.custom("Montserrat-SemiBold", size: 20))
                        .foregroundColor(Palette.burgundy)
                    Spacer()
                }
                .padding(.top, 8)

                // Stars selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your rating")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(.primary)
                    StarPicker(rating: $stars)
                }

                // Comment
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comment")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(.primary)
                    TextEditor(text: $comment)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Palette.grayLight)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.custom("Montserrat-Regular", size: 15))
                }

                // Photo
                VStack(alignment: .leading, spacing: 8) {
                    Text("Photo (optional)")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(.primary)

                    if let img = capturedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button {
                                capturedImage = nil
                                imageData = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .padding(8)
                        }

                        Button {
                            showCamera = true
                        } label: {
                            Label("Retake photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(PrimaryCapsuleButton(color: Palette.purple))
                        .padding(.top, 8)

                    } else {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take a photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(PrimaryCapsuleButton(color: Palette.purple))
                    }
                }

                if showValidation && comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Please, write a short comment.")
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                // Submit
                Button {
                    submit()
                } label: {
                    Text(controller.isSubmitting ? "Submitting..." : "Submit review")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(PrimaryCapsuleButton(color: Palette.burgundy))
                .disabled(controller.isSubmitting)

                if let err = controller.errorMsg {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .onReceive(NotificationCenter.default.publisher(for: .reviewDidCreate)) { _ in
            dismiss()
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { img in
                capturedImage = img
                imageData = img.jpegData(compressionQuality: 0.85)
            }
        }
    }

    private func submit() {
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showValidation = true
            return
        }
        controller.submit(
            restaurantId: restaurant.id,
            stars: stars,
            comment: trimmed,
            imageData: imageData
        )
    }
}

// MARK: - StarPicker (interactivo)
private struct StarPicker: View {
    @Binding var rating: Int
    private let max = 5

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...max, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: 24))
                    .foregroundColor(Palette.burgundy)
                    .onTapGesture { rating = i }
            }
        }
        .padding(.vertical, 4)
    }
}
