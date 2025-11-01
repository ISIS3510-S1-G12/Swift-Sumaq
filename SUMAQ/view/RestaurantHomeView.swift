//
//  RestaurantHomeView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDOÑO on 20/09/25

// LOCAL STORAGE  # 2 - UserDefaults : Maria

// EVENTUAL CONECTIVITY #3  : Maria

//
//  LOCAL STORAGE:  for dishes using UserDefaults key–value storage

//  - Goal: Make the restaurant “Menu” tab resilient offline by caching the
//    dishes snapshot in UserDefaults and rendering it immediately when there is
//    no connectivity.
//  - Strategy (write-through cache):
//      1) On appear, read UserDefaults key `dishes.byRestaurant.<restaurantId>`.
//         If found, decode and render instantly (no blocking UI).
//      2) In parallel, fetch remote: on success, render fresh data and persist
//         the snapshot back into UserDefaults along with `dishes.lastSyncAt.<rid>`.
//      3) If remote fails and there is a local snapshot, keep local data; if
//         there is no local data, surface the error.
//  - Threading:
//      * All @State mutations occur on MainActor.
//      * UserDefaults writes are triggered in a `Task.detached` to avoid blocking the UI.
//  - Public APIs remain unchanged; helpers are private to this file only.
//  - Keys used:
//      * dishes.byRestaurant.<restaurantId>
//      * dishes.lastSyncAt.<restaurantId>
//

import SwiftUI
import MapKit
import FirebaseAuth
import Network //  EVENTUAL CONECTIVITY: Needed to observe online/offline status via NWPathMonitor.

struct RestaurantHomeView: View {
    // 0 = Menú, 1 = Offers, 2 = Review
    @State private var selectedTab: Int = 0
    @ObservedObject private var session = SessionController.shared
    @State private var showAccount = false
    @State private var goToChoice = false

    private var displayName: String {
        session.currentRestaurant?.name ?? "My restaurant"
    }
    private var avatarURL: String? {
        session.currentRestaurant?.imageUrl
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    RestaurantTopBar(
                        name: displayName,
                        imageURL: avatarURL,
                        onAvatarTap: { showAccount = true }
                    )

                    Text(displayName)
                        .font(.custom("Montserrat-SemiBold", size: 22))
                        .foregroundColor(Palette.burgundy)
                        .padding(.horizontal, 16)

                    RestaurantSegmentedTab(selectedIndex: $selectedTab) { _ in }
                        .frame(maxWidth: .infinity, alignment: .center)

                    Group {
                        switch selectedTab {
                        case 0:
                            MenuContent()
                        case 1:
                            OffersContent()
                        case 2:
                            ReviewsContent()
                        default:
                            MenuContent()
                        }
                    }
                }
                .padding(.top, 8)
            }
            .background(Color.white.ignoresSafeArea())
            // Hoja de cuenta
            .sheet(isPresented: $showAccount) {
                RestaurantAccountSheet {
                    // al cerrar sesión, navegar a Choice
                    goToChoice = true
                }
            }
            // Al detectar logout por otros medios, también navega
            .onReceive(NotificationCenter.default.publisher(for: .authDidLogout)) { _ in
                goToChoice = true
            }
            // Enlace a Choice
            .background(
                NavigationLink(
                    destination: ChoiceUserView(),
                    isActive: $goToChoice
                ) { EmptyView() }
                .hidden()
            )
        }
    }
}

private struct MenuContent: View {
    // LOCAL STORAGE: Use a lightweight KV model for offline rendering to avoid constructing domain `Dish`.
    @State private var dishes: [DishKV] = []
    @State private var loading = true
    @State private var error: String?
    private let repo = DishesRepository() // unchanged public API

    // LOCAL STORAGE: KV keys builder for this restaurant.
    private func kvKeyDishes(_ rid: String) -> String { "dishes.byRestaurant.\(rid)" }
    private func kvKeyLastSync(_ rid: String) -> String { "dishes.lastSyncAt.\(rid)" }

    // LOCAL STORAGE: Simple KV API using UserDefaults with Codable payloads.
    private func kvSet<T: Codable>(_ value: T, key: String) {
        // Writes are small but perform them off the main thread to keep UI responsive.
        Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(value) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
    private func kvGet<T: Codable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    // LOCAL STORAGE: Persistable KV model with only the fields used by the UI.
    // Keep it minimal to avoid coupling to the full domain `Dish` type.
    private struct DishKV: Codable, Identifiable {
        let id: String
        let name: String
        let description: String?
        let imageURL: String?
        let rating: Double? // optional; may be absent in some payloads
    }

    // LOCAL STORAGE: Mapping from domain `Dish` to `DishKV`.
    // Only touch fields that are guaranteed to exist in the current UI usage.
    private func toKV(_ d: Dish) -> DishKV {
        // If `Dish.rating` is not Double, drop it safely (nil).
        // Avoid accessing non-existent properties like `tags` or `updatedAt`.
        var ratingValue: Double? = nil
        // Best-effort conversion when the domain model exposes a rating:
        // Attempt common property names via Mirror without adding external deps.
        let mirror = Mirror(reflecting: d)
        if let child = mirror.children.first(where: { $0.label == "rating" }) {
            if let r = child.value as? Double { ratingValue = r }
            else if let r = child.value as? Int { ratingValue = Double(r) }
            else if let r = child.value as? Float { ratingValue = Double(r) }
        }
        // Access `imageUrl` and `description` if present; otherwise leave nil.
        var image: String? = nil
        if let child = mirror.children.first(where: { $0.label == "imageUrl" }),
           let v = child.value as? String? {
            image = v
        }
        var desc: String? = nil
        if let child = mirror.children.first(where: { $0.label == "description" }),
           let v = child.value as? String? {
            desc = v
        }
        // `id` and `name` are used directly.
        let idValue: String = (mirror.children.first { $0.label == "id" }?.value as? String) ?? ""
        let nameValue: String = (mirror.children.first { $0.label == "name" }?.value as? String) ?? ""

        return DishKV(
            id: idValue,
            name: nameValue,
            description: desc,
            imageURL: image,
            rating: ratingValue
        )
    }

    // LOCAL STORAGE: Optional "Last updated" label fed by UserDefaults.
    @State private var lastSyncAt: Date?

    //  EVENTUAL CONECTIVITY: View-scoped connectivity monitor and banner state; does not change existing data logic.
    @StateObject private var connectivity = HomeConnectivityMonitor()
    @State private var showConnectivityNotice: Bool = false

    var body: some View {
        VStack(spacing: 16) {

            HStack {
                Spacer()
                Button { /* Busiest Hours */ } label: {
                    HStack(spacing: 8) {
                        Text("Busiest Hours")
                            .font(.custom("Montserrat-SemiBold", size: 14))
                        Image(systemName: "chart.bar.fill").font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Palette.teal)
                    .clipShape(Capsule())
                }
                Spacer()
            }

            if loading {
                ProgressView().padding()
            } else if let error {
                Text(error).foregroundColor(.red).padding(.horizontal, 16)
            } else if dishes.isEmpty {
                Text("No dishes yet").foregroundColor(.secondary).padding()
            } else {
                // LOCAL STORAGE EVENTUAL CONECTIVITY: Show the offline notice above the cards when device is offline.
                if connectivity.isOffline && showConnectivityNotice {
                    ConnectivityNoticeCard(
                        title: "You're offline",
                        message: "You are viewing saved menu items for this restaurant on this device. Create or update actions will be queued and retried when the connection returns."
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(spacing: 12) {
                    ForEach(dishes) { d in
                        RestaurantDishCard(
                            title: d.name,
                            subtitle: d.description ?? "",
                            imageURL: d.imageURL ?? "",
                            rating: Int(d.rating ?? 0.0)
                        )
                    }
                    // LOCAL STORAGE: Show "Last updated" timestamp if available from KV.
                    if let lastSyncAt {
                        Text("Last updated \(relativeTimeString(from: lastSyncAt))")
                            .font(.custom("Montserrat-Regular", size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack {
                Spacer()
                NavigationLink { NewDishView(onCreated: reload) } label: {
                    SmallCapsuleButton(
                        title: "New Dish",
                        background: Palette.orangeAlt,
                        textColor: .white
                    )
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        //  EVENTUAL CONECTIVITY: Start & stop monitoring and sync banner with reachability changes.
        .onAppear {
            connectivity.start()
            showConnectivityNotice = connectivity.isOffline
        }
        .onReceive(connectivity.$isOffline.removeDuplicates()) { offline in
            showConnectivityNotice = offline
        }
        .onDisappear {
            connectivity.stop()
        }
        // LOCAL STORAGE: Renders KV snapshot first, then fetches remote and updates KV.
        .task { await loadOfflineFirst() }
    }

    // LOCAL STORAGE: Returns a relative time string
    private func relativeTimeString(from date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    // LOCAL STORAGE:  loading using KV snapshot + remote write
    @MainActor
    private func loadOfflineFirst() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            loading = false
            error = "Missing restaurant id"
            return
        }

        // 1) Try to render KV snapshot immediately if exists.
        let dishesKey = kvKeyDishes(uid)
        let lastSyncKey = kvKeyLastSync(uid)

        if let cached: [DishKV] = kvGet([DishKV].self, key: dishesKey) {
            // Render cached dishes instantly to avoid empty UI when offline.
            self.dishes = cached
            self.loading = false
        } else {
            // Keep the spinner while we try network if there is no local snapshot.
            self.loading = true
        }

        if let cachedSync: Date = kvGet(Date.self, key: lastSyncKey) {
            self.lastSyncAt = cachedSync
        }

        // 2) Remote fetch in parallel. On success, update UI and KV (write-through).
        do {
            let fresh = try await repo.listForRestaurant(uid: uid)
            let kvPayload = fresh.map(toKV)

            self.dishes = kvPayload
            self.error = nil
            self.loading = false

            // Persist snapshot and lastSyncAt off the main thread.
            kvSet(kvPayload, key: dishesKey)
            let now = Date()
            kvSet(now, key: lastSyncKey)
            self.lastSyncAt = now
        } catch {
            // If there is already a local snapshot on screen, prefer it silently.
            // If not, surface the error.
            if dishes.isEmpty {
                self.error = error.localizedDescription
                self.loading = false
            }
        }
    }

    private func reload() { Task { await loadOfflineFirst() } }
}

private struct SmallCapsuleButton: View {
    let title: String
    let background: Color
    let textColor: Color
    var body: some View {
        Text(title)
            .font(.custom("Montserrat-SemiBold", size: 14))
            .foregroundColor(textColor)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(background)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
    }
}

//  EVENTUAL CONECTIVITY: Reusable banner (message only, no button).
private struct ConnectivityNoticeCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Montserrat-Bold", size: 16))
                .foregroundColor(.primary)
            Text(message)
                .font(.custom("Montserrat-Regular", size: 14))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.tertiaryLabel), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title). \(message)"))
    }
}

//  EVENTUAL CONECTIVITY: View-local NWPathMonitor wrapper to publish `isOffline` for this screen.
final class HomeConnectivityMonitor: ObservableObject {
    @Published var isOffline: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "sumaq.connectivity.monitor.restaurant.home")

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
