import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct CamaraPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var imageData: Data?

    @State private var selection: PhotosPickerItem? = nil
    @State private var previewImage: UIImage? = nil

    @State private var showCamera = false
    @State private var cameraUnavailableAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if let ui = previewImage {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Palette.grayLight)
                        Text("No image selected")
                            .font(.custom("Montserrat-Regular", size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 180)
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 12) {
                    PhotosPicker(selection: $selection, matching: .images) {
                        Text("Choose from Library")
                            .font(.custom("Montserrat-SemiBold", size: 16))
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(PrimaryCapsuleButton(color: Palette.purple))

                    Button {
                        Task { await openCamera() }
                    } label: {
                        Text("Take Photo")
                            .font(.custom("Montserrat-SemiBold", size: 16))
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(PrimaryCapsuleButton(color: Palette.orange))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("Pick image")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") { dismiss() }
                        .disabled(imageData == nil)
                }
            }
        }
        .onChange(of: selection) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    applyPicked(ui)
                } else {
                    self.imageData = nil
                    self.previewImage = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            SystemCameraPicker { image in
                if let image { 
                    applyPicked(image)
                }
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .alert("Camera Unavailable", isPresented: $cameraUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings or use the photo library.")
        }
    }

    private func applyPicked(_ ui: UIImage) {
        self.previewImage = ui
        self.imageData = ui.jpegData(compressionQuality: 0.9)
    }

    private func openCamera() async {
        // Verifica si el dispositivo tiene cámara
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            DispatchQueue.main.async {
                self.cameraUnavailableAlert = true
            }
            return
        }
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            DispatchQueue.main.async {
                self.showCamera = true
            }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            DispatchQueue.main.async {
                self.showCamera = granted
                if !granted { 
                    self.cameraUnavailableAlert = true 
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.cameraUnavailableAlert = true
            }
        @unknown default:
            DispatchQueue.main.async {
                self.cameraUnavailableAlert = true
            }
        }
    }
}

private struct SystemCameraPicker: UIViewControllerRepresentable {
    var onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = context.coordinator
        vc.allowsEditing = true
        vc.cameraDevice = .rear
        vc.cameraFlashMode = .auto
        return vc
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DispatchQueue.main.async {
                self.onFinish(nil)
            }
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let img = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            DispatchQueue.main.async {
                self.onFinish(img)
            }
        }
    }
}
