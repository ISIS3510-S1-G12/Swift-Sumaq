//
//  DoReviewView.swift
//  SUMAQ
//
//

import SwiftUI
import UIKit

struct DoReviewView: View {
    
    let userId: String
    let authorUsername: String
    let restaurantId: String
    let restaurantName: String
    @StateObject private var controller = ReviewsController()
    @State private var rating: Double = 0
    @State private var username: String = ""
    @State private var comment: String = ""
    @FocusState private var isCommentFocused: Bool
    @State private var showPhotoSheet = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var pickedImage: UIImage? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TopBar()

                header
                VStack(spacing: 12) {
                
                    InteractiveStars(rating: $rating)
                        .padding(.top, 4)

                    // Username (si quieres dejarlo fijo, puedes deshabilitarlo)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username")
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundStyle(Palette.grayDark)
                        TextField("Username", text: Binding(
                            get: { username.isEmpty ? authorUsername : username },
                            set: { username = $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Palette.grayLight.opacity(0.35))
                        )
                    }

                    // Review
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Review")
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundStyle(Palette.grayDark)
                        TextField("Write your Review here", text: $comment, axis: .vertical)
                            .lineLimit(4...6)
                            .focused($isCommentFocused)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Palette.grayLight.opacity(0.35))
                            )
                    }

                    // Foto
                    photoBlock
                }
                .padding(.horizontal, 16)

                // Submit
                Button(action: submit) {
                    Text(controller.isLoading ? "Submitting..." : "Submit")
                        .font(.custom("Montserrat-SemiBold", size: 14))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.burgundy)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .disabled(!formIsValid || controller.isLoading)

                // Error
                if let err = controller.errorMessage {
                    Text(err)
                        .font(.custom("Montserrat-Regular", size: 13))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear { username = authorUsername }
        .sheet(isPresented: $showCamera) {
            PhotoPicker(source: .camera) { img in
                pickedImage = img
            }
        }
        .sheet(isPresented: $showLibrary) {
            PhotoPicker(source: .library) { img in
                pickedImage = img
            }
        }
        .confirmationDialog("Agregar foto", isPresented: $showPhotoSheet, titleVisibility: .visible) {
            Button("Tomar foto") { showCamera = true }
            Button("Elegir de galería") { showLibrary = true }
            if pickedImage != nil { Button("Eliminar foto", role: .destructive) { pickedImage = nil } }
            Button("Cancelar", role: .cancel) {}
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.burgundy)
                }
                Spacer()
                Text(restaurantName)
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundStyle(Palette.burgundy)
                Spacer()
                Color.clear.frame(width: 20, height: 20)
            }
            .padding(.horizontal, 16)

            Divider().overlay(Palette.burgundy).padding(.horizontal, 16)
        }
    }

    // MARK: - Foto block
    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let img = pickedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            pickedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .shadow(radius: 2)
                        }
                        .padding(8)
                    }
            }

            HStack(spacing: 10) {
                Button {
                    showPhotoSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text(pickedImage == nil ? "Agregar foto" : "Cambiar foto")
                    }
                    .font(.custom("Montserrat-SemiBold", size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Palette.burgundy)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if pickedImage != nil {
                    Text("Foto adjunta")
                        .font(.custom("Montserrat-Regular", size: 12))
                        .foregroundStyle(Palette.grayDark)
                }
                Spacer()
            }
        }
    }

    private var formIsValid: Bool {
        rating > 0 && !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Submit
    private func submit() {
        Task {
            let ok = await controller.createReview(
                userId: userId,
                authorUsername: username.isEmpty ? authorUsername : username,
                restaurantId: restaurantId,
                rating: rating,
                comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
                photo: pickedImage
            )
            if ok { dismiss() }
        }
    }
}

private struct InteractiveStars: View {
    @Binding var rating: Double   
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= Int(rating) ? "star.fill" : "star")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Palette.burgundy)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            rating = Double(i)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DoReviewView(
        userId: "uid_123",
        authorUsername: "rpl_03",
        restaurantId: "Restaurants/0W77nA98U9ccWQKdb5unvcWHwYp1",
        restaurantName: "La Puerta"
    )
}
