//
//  NewDishView.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//


import SwiftUI
import PhotosUI
import FirebaseAuth

struct NewDishView: View {
    var onCreated: (() -> Void)? = nil

    @State private var name = ""
    @State private var description = ""
    @State private var price = ""
    @State private var rating = "0"
    @State private var imageData: Data? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var cameraUnavailableAlert = false
    @State private var showSuccessAlert = false
    @State private var dishType = "main"
    @State private var tagsText = ""          // cosas como "good, spicy"

    @State private var isSaving = false
    @State private var error: String?

    private let repo = DishesRepository()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                LabeledField(title: "Name",
                             text: $name,
                             placeholder: "Dish name",
                             keyboard: .default,
                             autocap: .words,
                             labelColor: Palette.teal)

                LabeledTextArea(title: "Description",
                                text: $description,
                                placeholder: "Write the description here",
                                labelColor: Palette.teal)

                LabeledField(title: "Price",
                             text: $price,
                             placeholder: "20000",
                             keyboard: .decimalPad,
                             labelColor: Palette.teal)

                LabeledField(title: "Rating (0–5)",
                             text: $rating,
                             placeholder: "4",
                             keyboard: .numberPad,
                             labelColor: Palette.teal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Image")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(Palette.teal)

                    if let imageData, let ui = UIImage(data: imageData) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipped()
                            .cornerRadius(12)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Palette.grayLight)
                                .frame(height: 140)
                            
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                
                                Text("No image selected")
                                    .font(.custom("Montserrat-Regular", size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text("Choose from Library")
                                .font(.custom("Montserrat-SemiBold", size: 16))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(PrimaryCapsuleButton(color: Palette.purple))

                        Button {
                            Task { await openCamera() }
                        } label: {
                            Text("Take Photo")
                                .font(.custom("Montserrat-SemiBold", size: 16))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(PrimaryCapsuleButton(color: Palette.orange))
                    }
                    .onChange(of: photoItem) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                self.imageData = data
                            }
                        }
                    }
                }

                LabeledField(title: "Dish Type",
                             text: $dishType,
                             placeholder: "main / side / drink ...",
                             keyboard: .default,
                             labelColor: Palette.teal)

                LabeledField(title: "Tags",
                             text: $tagsText,
                             placeholder: "good, spicy",
                             keyboard: .default,
                             labelColor: Palette.teal)

                if let error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, 4)
                }

                Button {
                    Task { await save() }
                } label: {
                    Text(isSaving ? "Creating..." : "Submit")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(PrimaryCapsuleButton(color: Palette.teal))
                .disabled(isSaving || name.isEmpty || description.isEmpty || imageData == nil || price.isEmpty)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("New Dish")
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    self.imageData = imageData
                }
            }
        }
        .alert("Camera Unavailable", isPresented: $cameraUnavailableAlert) {
            Button("OK") { }
        } message: {
            Text("Camera is not available on this device.")
        }
        .alert("Dish Created Successfully!", isPresented: $showSuccessAlert) {
            Button("OK") {
                onCreated?()
            }
        } message: {
            Text("Your dish has been added to the menu successfully.")
        }
    }

    private func save() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let imageData else { error = "Please select an image"; return }
        isSaving = true; error = nil
        do {
            try await repo.create(
                forRestaurantUid: uid,
                name: name,
                description: description,
                price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0,
                rating: Int(rating) ?? 0,
                imageData: imageData,
                dishType: dishType,
                dishesTags: tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            )
            isSaving = false
            showSuccessAlert = true
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }
    
    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraUnavailableAlert = true
            return
        }
        showCamera = true
    }
}

private struct LabeledTextArea: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var height: CGFloat = 110
    var labelColor: Color = Palette.teal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(labelColor)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.custom("Montserrat-Regular", size: 16))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $text)
                    .font(.custom("Montserrat-Regular", size: 16))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: height, alignment: .topLeading)
            }
            .background(Palette.grayLight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType {
        case camera
        case photoLibrary
    }
    
    let sourceType: SourceType
    let onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType == .camera ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        
        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
