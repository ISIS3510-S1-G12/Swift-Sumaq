import SwiftUI
import FirebaseAuth
import Network // UPDATE EVENTUAL CONECTIVITY: Used to monitor online/offline status via NWPathMonitor.

// CACHING STRATEGY #2 NSCache : Maria

// UPDATE: NSCache-based in-memory caching for restaurant offers.
// UPDATE: This view caches offers per restaurantId in a static NSCache<NSString, NSArray>.
// UPDATE: On load(), it first serves cached data instantly (no loading spinner) if available,
// UPDATE: then fetches fresh data in the background and updates both UI and cache.
// UPDATE: On reload() (after creating a new offer), it invalidates the cache before fetching.

// EVENTUAL CONECTIVITY 2: Maria

struct OffersContent: View {
    // UPDATE: Static cache lives for the app session; key = restaurantId, value = NSArray of Offer.
    @MainActor private static let cache = NSCache<NSString, NSArray>() // UPDATE: In-memory LRU-like cache managed by the system.

    @State private var searchText: String = ""
    @State private var offers: [Offer] = []
    @State private var loading = true
    @State private var error: String?

    private let repo = OffersRepository()

    // UPDATE EVENTUAL CONECTIVITY: View-scoped connectivity monitor and banner state.
    // UPDATE EVENTUAL CONECTIVITY: Use a view-local monitor name to avoid type collisions with other files.
    @StateObject private var connectivity = OffersConnectivityMonitor()
    @State private var showConnectivityNotice: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                SearchBar(text: $searchText, color: Palette.orangeAlt)
                Spacer()
            }
            .padding(.horizontal, 16)

            if loading {
                ProgressView().padding()
            } else if let error {
                Text(error).foregroundColor(.red).padding(.horizontal, 16)
            } else if filteredOffers.isEmpty {
                Text("No offers yet").foregroundColor(.secondary).padding()
            } else {
                // UPDATE EVENTUAL CONECTIVITY: Show the offline notice above the list of cards when device is offline.
                if connectivity.isOffline && showConnectivityNotice {
                    ConnectivityNoticeCard(
                        title: "You're offline",
                        message: "You are viewing saved offers for this restaurant on this device. Create or update actions will be queued and retried when the connection returns. We will notify you if any action cannot be completed."
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(spacing: 12) {
                    ForEach(filteredOffers) { off in
                        OfferCard(
                            title: off.title,
                            description: off.description,
                            imageURL: off.image,
                            price: off.price,
                            trailingEdit: { },
                            panelColor: Palette.tealLight
                        )
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack {
                Spacer()
                NavigationLink { NewOfferView(onCreated: reload) } label: {
                    SmallCapsuleButton(
                        title: "New Offer",
                        background: Palette.orangeAlt,
                        textColor: .white
                    )
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .task { await load() }
        // UPDATE EVENTUAL CONECTIVITY: Start/stop monitoring and keep banner in sync with reachability.
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
    }

    private var filteredOffers: [Offer] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return offers }
        return offers.filter {
            $0.title.lowercased().contains(term) ||
            $0.description.lowercased().contains(term) ||
            $0.tags.joined(separator: " ").lowercased().contains(term)
        }
    }

    // UPDATE: Load sequence with NSCache.
    // UPDATE: 1) If cached, present immediately and skip showing the spinner.
    // UPDATE: 2) Always refresh from network in the background and update cache+UI on success.
    private func load() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let cacheKey = NSString(string: uid) // UPDATE: Key by restaurantId.

        if let cachedArray = await MainActor.run(body: { OffersContent.cache.object(forKey: cacheKey) }) {
            if let cached = cachedArray as? [Offer] {
                await MainActor.run {
                    self.offers = cached     // UPDATE: Serve cached data instantly.
                    self.loading = false     // UPDATE: Avoid spinner if cache exists.
                    self.error = nil
                }
            }
        } else {
            await MainActor.run {
                self.loading = true        // UPDATE: No cache → show spinner while fetching.
                self.error = nil
            }
        }

        // UPDATE: Background refresh to keep data fresh, regardless of cache hit.
        Task.detached(priority: .userInitiated) {
            do {
                let fresh = try await repo.listForRestaurant(uid: uid)
                // UPDATE: Update cache with the latest snapshot.
                await MainActor.run {
                    OffersContent.cache.setObject(NSArray(array: fresh), forKey: cacheKey)
                    self.offers = fresh     // UPDATE: Reflect fresh data on UI.
                    self.loading = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    // UPDATE: Keep whatever is on screen; only surface error if nothing to show.
                    if self.offers.isEmpty {
                        self.error = error.localizedDescription
                        self.loading = false
                    }
                }
            }
        }
    }

    // UPDATE: Explicit reload after creating a new offer:
    // UPDATE: Invalidate the cache for this restaurant and trigger a fresh load.
    private func reload() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let cacheKey = NSString(string: uid)
        Task {
            await MainActor.run {
                OffersContent.cache.removeObject(forKey: cacheKey) // UPDATE: Ensure new offers appear immediately.
            }
            await load() // UPDATE: Re-run load sequence.
        }
    }
}

private struct SmallCapsuleButton: View {
    let title: String
    let background: Color
    var textColor: Color

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

// UPDATE EVENTUAL CONECTIVITY: Reusable banner (message only, no button).
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

// UPDATE EVENTUAL CONECTIVITY: View-local NWPathMonitor wrapper that publishes `isOffline`.
// UPDATE EVENTUAL CONECTIVITY: Named `OffersConnectivityMonitor` to avoid clashes with other files.
final class OffersConnectivityMonitor: ObservableObject {
    @Published var isOffline: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "sumaq.connectivity.monitor.offerscontent")

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
