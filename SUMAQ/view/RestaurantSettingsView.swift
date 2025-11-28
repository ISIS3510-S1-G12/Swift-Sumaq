//
//  RestaurantSettingsView.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 28/11/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit
import Network

struct RestaurantSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = SessionController.shared

    // MARK: - Editable fields (Restaurant)
    @State private var name: String = ""
    @State private var typeOfFood: String = ""
    @State private var address: String = ""
    @State private var offer: Bool = false

    @State private var openingTimeText: String = ""
    @State private var closingTimeText: String = ""

    @State private var latText: String = ""
    @State private var lonText: String = ""

    @State private var imageUrl: String = ""

    // Campos que no se editan pero se necesitan para el record local
    @State private var currentRating: Double = 0
    @State private var currentUpdatedAt: Date? = nil

    // MARK: - Profile picture
    @State private var restaurantPhotoURL: String?
    @State private var imageData: Data?
    @State private var showPhotoPicker = false

    // MARK: - Local storage / pending sync
    private let restaurantsDAO = RestaurantsDAO()
    @State private var hasLocalUnsyncedChanges = false
    @State private var lastLocalRecordForSync: RestaurantRecord?

    // MARK: - Messages
    @State private var infoMessage: String?   // gris
    @State private var errorMessage: String?  // rojo

    /// Callback para que el parent (RestaurantHomeView) pueda navegar a Choice al cerrar sesión.
    var onLoggedOut: (() -> Void)? = nil

    // Conectividad para auto-sync al volver el internet
    @StateObject private var connectivity = SettingsConnectivityMonitor()
    @State private var wasPreviouslyOnline: Bool = true

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Basic info
                Section(header: Text("Restaurant")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type of food")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("", text: $typeOfFood)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle(isOn: $offer) {
                        Text("Has active offers")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }

                // MARK: Location & Schedule
                Section(header: Text("Location & Schedule")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Address")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("", text: $address)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Opening time (int)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("", text: $openingTimeText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Closing time (int)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("", text: $closingTimeText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Latitude")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("", text: $latText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Longitude")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("", text: $lonText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // MARK: Profile Picture
                Section(header: Text("Profile Picture")) {
                    HStack(spacing: 16) {
                        // 1. Nueva imagen seleccionada
                        if let data = imageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        // 2. Si no hay nueva, usamos la URL actual (RemoteImage)
                        else if let url = restaurantPhotoURL, !url.isEmpty {
                            RemoteImage(urlString: url)
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        // 3. Placeholder
                        else {
                            Image(systemName: "building.2.crop.square")
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

                // MARK: Info / Error messages
                if let infoMessage {
                    Section {
                        Text(infoMessage)
                            .foregroundColor(.secondary) // gris
                            .font(.footnote)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red) // rojo
                            .font(.footnote)
                    }
                }

                // MARK: Actions
                Section {
                    Button {
                        Task { await saveRestaurantProfile() }
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
            .navigationTitle("Settings")
            .onAppear {
                loadCurrentRestaurant()
                connectivity.start()
                wasPreviouslyOnline = !connectivity.isOffline
            }
            .onDisappear {
                connectivity.stop()
            }
            .onReceive(connectivity.$isOffline.removeDuplicates()) { offline in
                let nowOnline = !offline
                // Pasamos de offline -> online y hay cambios pendientes
                if nowOnline && !wasPreviouslyOnline {
                    Task { await syncPendingChangesIfNeeded() }
                }
                wasPreviouslyOnline = nowOnline
            }
            .sheet(isPresented: $showPhotoPicker) {
                CamaraPicker(imageData: $imageData)
            }
        }
    }

    // MARK: - Load current restaurant data (offline-first)

    /// Carga la info editable del restaurante.
    /// 1) Intenta leer primero de SQLite (RestaurantsDAO)
    /// 2) Luego trae Firestore y sobreescribe SOLO si no hay cambios locales pendientes.
    private func loadCurrentRestaurant() {
        guard let appRestaurant = session.currentRestaurant else { return }

        // Valores rápidos desde AppRestaurant mientras llegan datos locales/remotos
        name = appRestaurant.name
        restaurantPhotoURL = appRestaurant.imageUrl
        imageUrl = appRestaurant.imageUrl ?? ""

        let restaurantId = appRestaurant.id

        // 1) OFFLINE PRIMERO: cargar de SQLite si existe
        Task {
            if let localRecord = try? restaurantsDAO.getMany(ids: [restaurantId]).first {
                apply(record: localRecord)
            }
        }

        // 2) Firestore (solo si no hay cambios locales pendientes)
        let db = Firestore.firestore()
        db.collection("Restaurants").document(restaurantId).getDocument { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    if self.errorMessage == nil {
                        self.errorMessage = "Could not load restaurant: \(error.localizedDescription)"
                    }
                }
                return
            }

            // Si hay cambios locales pendientes, no pisamos el formulario con datos remotos
            guard self.hasLocalUnsyncedChanges == false else { return }

            guard let snapshot = snapshot,
                  snapshot.exists,
                  let full = Restaurant(doc: snapshot) else {
                return
            }

            let record = RestaurantRecord(
                id: full.id,
                name: full.name,
                typeOfFood: full.typeOfFood,
                rating: full.rating,
                offer: full.offer,
                address: full.address,
                openingTime: full.opening_time,
                closingTime: full.closing_time,
                imageUrl: full.imageUrl,
                lat: full.lat,
                lon: full.lon,
                updatedAt: Date()
            )

            // Guardar también en SQLite
            do { try self.restaurantsDAO.upsert(record) } catch { }

            DispatchQueue.main.async {
                self.apply(record: record)
            }
        }
    }

    /// Aplica un `RestaurantRecord` al formulario y a los campos auxiliares.
    @MainActor
    private func apply(record: RestaurantRecord?) {
        guard let r = record else { return }
        self.name             = r.name
        self.typeOfFood       = r.typeOfFood
        self.address          = r.address ?? ""
        self.offer            = r.offer
        self.currentRating    = r.rating
        self.currentUpdatedAt = r.updatedAt

        if let ot = r.openingTime {
            self.openingTimeText = String(ot)
        }
        if let ct = r.closingTime {
            self.closingTimeText = String(ct)
        }
        if let lat = r.lat {
            self.latText = String(lat)
        }
        if let lon = r.lon {
            self.lonText = String(lon)
        }
        if let img = r.imageUrl, !img.isEmpty {
            self.imageUrl = img
            self.restaurantPhotoURL = img
        }
    }

    // MARK: - Save (local storage + Firestore / auto-sync)

    private func saveRestaurantProfile() async {
        isSaving = true
        infoMessage = nil
        errorMessage = nil
        defer { isSaving = false }

        guard let appRestaurant = session.currentRestaurant else {
            errorMessage = "No restaurant is loaded."
            return
        }

        // Normalizar campos de texto, valores opcionales para record y remoto
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let openingInt = Int(openingTimeText.trimmingCharacters(in: .whitespacesAndNewlines))
        let closingInt = Int(closingTimeText.trimmingCharacters(in: .whitespacesAndNewlines))
        let latDouble = Double(latText.trimmingCharacters(in: .whitespacesAndNewlines))
        let lonDouble = Double(lonText.trimmingCharacters(in: .whitespacesAndNewlines))
        let trimmedImage = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        let now = Date()

        // 1) Siempre construimos y guardamos el record en SQLite (local storage)
        let localRecord = RestaurantRecord(
            id: appRestaurant.id,
            name: name,
            typeOfFood: typeOfFood,
            rating: currentRating,
            offer: offer,
            address: trimmedAddress.isEmpty ? nil : trimmedAddress,
            openingTime: openingInt,
            closingTime: closingInt,
            imageUrl: trimmedImage.isEmpty ? nil : trimmedImage,
            lat: latDouble,
            lon: lonDouble,
            updatedAt: now
        )

        do {
            try restaurantsDAO.upsert(localRecord)
        } catch {
            print("RestaurantsDAO.upsert error: \(error)")
        }

        lastLocalRecordForSync = localRecord

        // 2) Verificar si hay conexión
        let isOnline = !connectivity.isOffline

        guard isOnline else {
            hasLocalUnsyncedChanges = true
            infoMessage = "You are offline. Changes were saved locally on this device. Whenever you recover connection, we will try to sync them automatically."
            return
        }

        // 3) Hay internet SINCRONIZA INMEDIATAMENTE
        await syncToServer(from: localRecord)
    }

    // Sincroniza un RestaurantRecord específico con Firestore + Storage
    private func syncToServer(from record: RestaurantRecord) async {
        let db = Firestore.firestore()

        do {
            var mutableImageUrl = record.imageUrl ?? ""

            // 1. Subir foto si hay nueva
            if let data = imageData {
                let urlString = try await uploadRestaurantImageData(data, for: record.id)
                await MainActor.run {
                    self.restaurantPhotoURL = urlString
                    self.imageData = nil
                }
                mutableImageUrl = urlString
            }

            // 2. Construir payload para Firestore
            var data: [String: Any] = [
                "name": record.name,
                "typeOfFood": record.typeOfFood,
                "offer": record.offer
            ]

            if let addr = record.address, !addr.isEmpty {
                data["address"] = addr
            }

            if let openingInt = record.openingTime {
                data["opening_time"] = openingInt
            }

            if let closingInt = record.closingTime {
                data["closing_time"] = closingInt
            }

            if let latDouble = record.lat {
                data["lat"] = latDouble
            }

            if let lonDouble = record.lon {
                data["lon"] = lonDouble
            }

            if !mutableImageUrl.isEmpty {
                data["imageUrl"] = mutableImageUrl
            }

            try await db.collection("Restaurants").document(record.id).updateData(data)

            // 3. Refrescar SessionController y marcar como sincronizado
            await MainActor.run {
                self.session.reloadCurrentRestaurant()
                self.hasLocalUnsyncedChanges = false
                self.infoMessage = nil
                self.errorMessage = nil
            }

            let syncedRecord = RestaurantRecord(
                id: record.id,
                name: record.name,
                typeOfFood: record.typeOfFood,
                rating: record.rating,
                offer: record.offer,
                address: record.address,
                openingTime: record.openingTime,
                closingTime: record.closingTime,
                imageUrl: mutableImageUrl.isEmpty ? nil : mutableImageUrl,
                lat: record.lat,
                lon: record.lon,
                updatedAt: Date()
            )
            try? restaurantsDAO.upsert(syncedRecord)

        } catch {
            await MainActor.run {
                self.errorMessage = "Network error: \(error.localizedDescription)\nYour changes are still saved locally. We will try to sync them when the connection returns."
                self.hasLocalUnsyncedChanges = true
            }
        }
    }

    // Llamado cuando el monitor detecta que pasó de offline  A ONLINE
    private func syncPendingChangesIfNeeded() async {
        guard hasLocalUnsyncedChanges,
              let record = lastLocalRecordForSync else { return }
        await syncToServer(from: record)
    }

    // MARK: - Upload image to Storage

    private func uploadRestaurantImageData(_ data: Data, for restaurantId: String) async throws -> String {
        let storageRef = Storage.storage()
            .reference()
            .child("restaurants/\(restaurantId)/profile.jpg")

        _ = try await storageRef.putDataAsync(data, metadata: nil)
        let url = try await storageRef.downloadURL()
        return url.absoluteString
    }

    // MARK: - Logout

    private func signOut() {
        infoMessage = nil
        errorMessage = nil
        do {
            try Auth.auth().signOut()
            KeychainHelper.shared.deleteOfflineCredentials()
            SessionController.shared.endUserSession()
            onLoggedOut?()
            dismiss()
        } catch {
            errorMessage = "Could not sign out: \(error.localizedDescription)"
        }
    }

    // MARK: - Saving state
    @State private var isSaving: Bool = false
}

//  EVENTUAL CONECTIVITY: Monitor local para Settings (offline/online)
final class SettingsConnectivityMonitor: ObservableObject {
    @Published var isOffline: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "sumaq.connectivity.monitor.restaurant.settings")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOffline = (path.status != .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
