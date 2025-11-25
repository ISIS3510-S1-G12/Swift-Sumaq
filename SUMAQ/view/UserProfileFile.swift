import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = SessionController.shared

    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var budgetText: String = ""
    @State private var diet: String = ""
    
    @State private var userPhotoData: String?
    @State private var imageData: Data?

    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var showPhotoPicker = false

    var body: some View {
        Form {

            // MARK: Profile Section
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("", text: $email)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Username")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("", text: $username)
                        .textFieldStyle(.roundedBorder)
                }
            } header: {
                Text("Profile")
            }

            // MARK: Preferences Section
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Budget (int)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("", text: $budgetText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Diet")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("", text: $diet)
                        .textFieldStyle(.roundedBorder)
                }
            } header: {
                Text("Preferences")
            }

            // MARK: Profile Picture
            Section(header: Text("Profile Picture")) {
                HStack(spacing: 16) {
                    // 1. Nueva imagen seleccionada con CamaraPicker → prioridad
                    if let data = imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    // 2. Si no hay nueva, usamos la URL actual (RemoteImage)
                    else if let url = userPhotoData, !url.isEmpty {
                        RemoteImage(urlString: url)
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    // 3. Placeholder
                    else {
                        Image(systemName: "person.crop.square")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .foregroundColor(.secondary)
                    }

                    Button("Choose photo") {
                        showPhotoPicker = true
                    }
                }
            }

            // Errors
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }

            // Save + Logout
            Section {
                Button {
                    Task { await saveProfile() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save changes")
                    }
                }

                Button(role: .destructive) {
                    signOut()
                } label: {
                    Text("Sign out")
                }
            }
        }
        .navigationTitle("Profile")
        .onAppear { loadCurrentUser() }
        .sheet(isPresented: $showPhotoPicker) {
            CamaraPicker(imageData: $imageData)
        }
    }

    // MARK: Load Data (Firestore/Auth + overrides de UserDefaults)

    private func loadCurrentUser() {
        // 1. Cargar desde SessionController / Firestore (si ya lo tienes)
        if let appUser = session.currentUser {
            displayName   = appUser.name
            email         = appUser.email
            username      = appUser.username ?? ""
            diet          = appUser.diet ?? ""
            budgetText    = appUser.budget != nil ? String(appUser.budget!) : ""
            userPhotoData = appUser.profilePictureURL
        } else if let user = Auth.auth().currentUser {
            // Fallback básico
            displayName = user.displayName ?? ""
            email       = user.email ?? ""
        }

        // 2. Encima de eso, si hay caché local, lo aplicamos
        if let uid = session.firebaseUid,
           let cached = LocalProfileCache.load(uid: uid) {
            displayName   = cached.name
            email         = cached.email
            username      = cached.username
            budgetText    = cached.budget
            diet          = cached.diet
            userPhotoData = cached.photoURL ?? userPhotoData
        }
    }

    // MARK: Save (Firebase si hay red + UserDefaults siempre)

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        guard let uid = session.firebaseUid else {
            errorMessage = "No user is logged in."
            return
        }

        let isOnline = NetworkHelper.shared.isConnectedToNetwork()

        // Siempre guardamos en caché local (para offline / reabrir pantalla)
        LocalProfileCache.save(
            uid: uid,
            name: displayName,
            email: email,
            username: username,
            budget: budgetText,
            diet: diet,
            photoURL: userPhotoData
        )

        // Si no hay internet → solo caché local y mensaje
        guard isOnline else {
            errorMessage = "You are offline. Changes were saved locally on this device. Whenever you recover connection, all you have to do is save your changes one more time"
            return
        }

        // Hay internet → intentamos sincronizar con Firebase
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user is logged in."
            return
        }

        do {
            // 1. Subir foto si hay nueva
            if let data = imageData {
                let urlString = try await uploadProfileImageData(data, for: uid)
                userPhotoData = urlString
                imageData = nil

                // Actualizar en caché la nueva URL
                LocalProfileCache.save(
                    uid: uid,
                    name: displayName,
                    email: email,
                    username: username,
                    budget: budgetText,
                    diet: diet,
                    photoURL: urlString
                )
            }

            // 2. Firebase Auth
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            if email != user.email {
                try await user.updateEmail(to: email)
            }

            // 3. Firestore
            let db = Firestore.firestore()
            var data: [String: Any] = [
                "name": displayName,
                "email": email,
                "username": username,
                "diet": diet
            ]

            if let budgetInt = Int(budgetText) {
                data["budget"] = budgetInt
            }
            if let urlString = userPhotoData {
                data["preferences.profile_picture"] = urlString
            }

            try await db.collection("Users").document(uid).updateData(data)

            // 4. Refrescar SessionController para que TopBar vea los cambios
            session.reloadCurrentUser()

        } catch {
            errorMessage = "Network error: \(error.localizedDescription)\nYour changes are still saved locally. Whenever you recover connect, all you have to do is save your changes one more time"
        }
    }

    // MARK: Logout

    private func signOut() {
        do {
            try Auth.auth().signOut()
            SessionController.shared.endUserSession()
        } catch {
            errorMessage = "Could not sign out: \(error.localizedDescription)"
        }
    }

    private func uploadProfileImageData(_ data: Data, for uid: String) async throws -> String {
        let storageRef = Storage.storage()
            .reference()
            .child("users/\(uid)/profile.jpg")

        _ = try await storageRef.putDataAsync(data, metadata: nil)
        let url = try await storageRef.downloadURL()
        return url.absoluteString
    }
}

// MARK: - Local profile cache (UserDefaults)

private struct LocalProfileCache {
    private static func key(_ uid: String, _ field: String) -> String {
        "profile.\(uid).\(field)"
    }

    static func save(
        uid: String,
        name: String,
        email: String,
        username: String,
        budget: String,
        diet: String,
        photoURL: String?
    ) {
        let d = UserDefaults.standard
        d.set(name,     forKey: key(uid, "name"))
        d.set(email,    forKey: key(uid, "email"))
        d.set(username, forKey: key(uid, "username"))
        d.set(budget,   forKey: key(uid, "budget"))
        d.set(diet,     forKey: key(uid, "diet"))
        d.set(photoURL, forKey: key(uid, "photoURL"))
    }

    static func load(uid: String) -> (name: String,
                                      email: String,
                                      username: String,
                                      budget: String,
                                      diet: String,
                                      photoURL: String?)? {
        let d = UserDefaults.standard

        guard let name = d.string(forKey: key(uid, "name")),
              let email = d.string(forKey: key(uid, "email")) else {
            return nil
        }

        let username = d.string(forKey: key(uid, "username")) ?? ""
        let budget   = d.string(forKey: key(uid, "budget")) ?? ""
        let diet     = d.string(forKey: key(uid, "diet")) ?? ""
        let photoURL = d.string(forKey: key(uid, "photoURL"))

        return (name, email, username, budget, diet, photoURL)
    }
}
