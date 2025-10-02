//
//  AddReviewView.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import SwiftUI
import PhotosUI

struct AddReviewView: View {
    let restaurant: Restaurant

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = ReviewsController()

    @State private var stars: Int = 0
    @State private var comment: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    private var imageData: Data? { previewImage?.jpegData(compressionQuality: 0.85) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Encabezado simple
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Palette.burgundy)
                    }
                    Spacer()
                    Text("New review")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .foregroundColor(Palette.burgundy)
                    Spacer()
                    Color.clear.frame(width: 28)    // balancea el back
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Nombre del restaurante
                Text(restaurant.name)
                    .font(.custom("Montserrat-SemiBold", size: 22))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                // Selector de estrellas
                StarSelector(rating: $stars)
                    .padding(.horizontal, 16)

                // Comentario
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.custom("Montserrat-SemiBold", size: 14))
                        .foregroundColor(Palette.burgundy)
                    TextEditor(text: $comment)
                        .frame(minHeight: 110)
                        .padding(10)
                        .background(Palette.grayLight)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 16)

                // Picker de imagen + preview (opcional)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add a photo (optional)")
                        .font(.custom("Montserrat-SemiBold", size: 14))
                        .foregroundColor(Palette.burgundy)

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose photo")
                                .font(.custom("Montserrat-SemiBold", size: 15))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Palette.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(radius: 2, y: 1)
                    }
                    .onChange(of: pickerItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let img = UIImage(data: data) {
                                await MainActor.run { self.previewImage = img }
                            }
                        }
                    }

                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.grayLight, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)

                // Error
                if let msg = controller.errorMsg {
                    Text(msg)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Submit centrado
                Button {
                    controller.submit(restaurantId: restaurant.id,
                                      stars: stars,
                                      comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
                                      imageData: imageData)
                } label: {
                    Text(controller.isSubmitting ? "Submitting..." : "Submit review")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: 260, minHeight: 50)
                }
                .buttonStyle(PrimaryCapsuleButton(color: Palette.burgundy))
                .disabled(controller.isSubmitting || stars == 0 || comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 16)
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        // Cerrar al crear
        .onReceive(NotificationCenter.default.publisher(for: .reviewDidCreate)) { _ in
            dismiss()
        }
    }
}

// Selector interactivo de estrellas (1–5)
private struct StarSelector: View {
    @Binding var rating: Int
    private let max = 5

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...max, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Palette.orangeAlt)
                    .onTapGesture { rating = i }
            }
        }
    }
}
