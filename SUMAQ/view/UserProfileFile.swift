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

    // MARK: - Local Storage helper

    /// Construye un UserRecord con los datos actuales del formulario
    private func makeUserRecord(uid: String) -> UserRecord {
        UserRecord(
            id: uid,
            name: displayName,
            email: email,
            role: session.role?.rawValue ?? "user",
            budget: Int(budgetText),
            diet: diet.isEmpty ? nil : diet,
            profilePictureURL: userPhotoData,
            createdAt: nil,              // no tocamos created_at desde aquí
            updatedAt: Date()
        )
    }

    // MARK: Load Data (Firestore / Auth / SQLite fallback)
    private func loadCurrentUser() {
        // 0. Aseguramos que la DB local esté lista
        LocalStore.shared.configureIfNeeded()

        let isOnline = NetworkHelper.shared.isConnectedToNetwork()

        // 1. SI ESTOY ONLINE → uso SessionController (Firestore) y cacheo localmente
        if isOnline, let appUser = session.currentUser {
            displayName   = appUser.name
            email         = appUser.email
            username      = appUser.username ?? ""
            diet          = appUser.diet ?? ""
            budgetText    = appUser.budget != nil ? String(appUser.budget!) : ""
            userPhotoData = appUser.profilePictureURL

            if let uid = session.firebaseUid {
                let record = makeUserRecord(uid: uid)
                Task.detached(priority: .utility) {
                    try? LocalStore.shared.users.upsert(record)
                }
            }
            return
        }

        // 2. SI ESTOY OFFLINE → leo primero de SQLite
        if let uid = session.firebaseUid {
            do {
                if let cached = try LocalStore.shared.users.get(id: uid) {
                    displayName   = cached.name
                    email         = cached.email
                    username      = cached.username                           // si no lo tienes en UserRecord
                    budgetText    = cached.budget != nil ? String(cached.budget!) : ""
                    diet          = cached.diet ?? ""
                    userPhotoData = cached.profilePictureURL
                    return
                }
            } catch {
                print("Failed to load user from local DB:", error)
            }
        }

        // 3. Último recurso → datos básicos de Auth
        if let user = Auth.auth().currentUser {
            displayName = user.displayName ?? ""
            email       = user.email ?? ""
        }
    }


    // MARK: Save (Firestore + Auth + SQLite)
    private func saveProfile() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // uid del usuario actual
        guard let user = Auth.auth().currentUser,
              let uid = session.firebaseUid else {
            errorMessage = "No user is logged in."
            return
        }

        // 1. Aseguramos que la DB local esté configurada
        LocalStore.shared.configureIfNeeded()

        // 2. Detectar si hay internet
        let isOnline = NetworkHelper.shared.isConnectedToNetwork()

        // 3. Construimos el record que queremos guardar localmente
        let localRecord = UserRecord(
            id: uid,
            name: displayName,
            email: email,
            role: session.role?.rawValue ?? "user",
            budget: Int(budgetText),
            diet: diet.isEmpty ? nil : diet,
            profilePictureURL: userPhotoData,
            createdAt: session.currentUser?.createdAt,   // si la tienes en AppUser
            updatedAt: Date()
        )

        do {
            if isOnline {
                // ---------- ONLINE: Firebase + cache local ----------
                // 3.1 Subir foto (solo si hay nueva imagen)
                if let data = imageData {
                    let urlString = try await uploadProfileImageData(data, for: uid)
                    userPhotoData = urlString   // guardamos la nueva URL
                    imageData = nil
                }

                // 3.2 Actualizar Auth
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()

                if email != user.email {
                    try await user.updateEmail(to: email)
                }

                // 3.3 Actualizar Firestore
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

                // 3.4 Cache local (no importa si falla, no rompemos la UX)
                do {
                    try LocalStore.shared.users.upsert(localRecord)
                } catch {
                    print("Local user cache write failed: \(error)")
                }

                // 3.5 Volver a leer el usuario para refrescar TopBar
                session.reloadCurrentUser()
            } else {
                // ---------- OFFLINE: solo SQLite ----------
                try LocalStore.shared.users.upsert(localRecord)

                // Mensaje amigable opcional
                errorMessage = "You are offline. Changes were saved locally and will be synced when you go online."
            }

        } catch {
            // Solo errores “reales” (online). Offline ya lo manejamos arriba.
            errorMessage = error.localizedDescription
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
