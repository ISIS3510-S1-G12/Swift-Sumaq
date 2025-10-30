//
//  OffersUserView.swift
//  SUMAQ
//
//  Summary of GCD usage for this file:
//  - What: Offload CPU-bound filtering and grouping of offers to a background queue using Grand Central Dispatch (DispatchQueue).
//  - Where off-main: Filtering (text match) and grouping (Dictionary(grouping:)) are executed on a dedicated concurrent queue with QoS .userInitiated.
//  - Hop back to main: All @State mutations (filteredOffers, groupedOffers, loading, error) are assigned on DispatchQueue.main.
//  - Debounce/cancellation: A DispatchWorkItem is used to debounce search input and cancel in-flight background computations to avoid stale UI updates.
//
//  Rationale:
//  SwiftUI recomputes view bodies frequently on the main thread. Performing heavy list massaging (filtering/grouping) inside computed
//  properties can block the main thread and cause UI jank. Using GCD here ensures the UI remains responsive while background work runs.
//
//  Public API stability:
//  - No changes to repositories (OffersRepository, RestaurantsRepository).
//  - View external API remains the same (same initializer and properties).
//

import SwiftUI

struct OffersUserView: View {
    var embedded: Bool = false

    // MARK: - UI State
    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionOffersView? = nil
    @State private var selectedTab = 2

    // Raw data loaded from repositories
    @State private var offers: [Offer] = []
    @State private var restaurantsById: [String: Restaurant] = [:]

    // Derived data now backed by state (filled via GCD background work)
    // These used to be computed properties; moving them to @State avoids recomputing heavy work on main during view updates.
    @State private var filteredOffers: [Offer] = []
    @State private var groupedOffers: [String: [Offer]] = [:]

    @State private var loading = true
    @State private var error: String?

    private let offersRepo = OffersRepository()
    private let restaurantsRepo = RestaurantsRepository()

    // Screen tracking
    @State private var screenStartTime: Date?

    // MARK: - Concurrency (GCD) infrastructure
    // Dedicated queue for CPU-bound filtering and grouping. Using .concurrent allows multiple tasks if needed.
    private let filterQueue = DispatchQueue(label: "offers.filter.queue", qos: .userInitiated, attributes: .concurrent)

    // Debounce work item to cancel stale computations when the user keeps typing.
    @State private var pendingSearchWork: DispatchWorkItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !embedded {
                    TopBar()
                    SegmentedTabs(selectedIndex: $selectedTab)
                }

                SearchFilterChatBar(
                    text: $searchText,
                    selectedFilter: $selectedFilter,
                    onChatTap: { }
                )
                .padding(.horizontal, 16)

                if loading {
                    ProgressView().padding()
                } else if let error {
                    Text(error).foregroundColor(.red).padding(.horizontal, 16)
                } else if filteredOffers.isEmpty {
                    Text("No offers available").foregroundColor(.secondary).padding()
                } else {
                    ForEach(groupedOffers.keys.sorted(), id: \.self) { rid in
                        Group {
                            OffersSectionHeader(title: restaurantsById[rid]?.name ?? "Restaurant")
                            VStack(spacing: 12) {
                                ForEach(groupedOffers[rid] ?? []) { off in
                                    OfferCard(
                                        title: off.title,
                                        description: off.description,
                                        imageURL: off.image,
                                        price: off.price
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.top, embedded ? 0 : 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            screenStartTime = Date()
            SessionTracker.shared.trackScreenView(ScreenName.offers, category: ScreenCategory.mainNavigation)

            // If data was previously loaded (e.g., returning to the screen), recompute derived data once.
            scheduleFilteringAndGrouping(term: searchText, sourceOffers: offers)
        }
        .onDisappear {
            if let startTime = screenStartTime {
                let duration = Date().timeIntervalSince(startTime)
                SessionTracker.shared.trackScreenEnd(ScreenName.offers, duration: duration, category: ScreenCategory.mainNavigation)
            }
            // Cancel any pending background work when leaving the screen to avoid wasted CPU.
            pendingSearchWork?.cancel()
        }
        // Async network load is kept as-is; the GCD strategy applies to post-fetch transformations only.
        .task { await load() }
        // Debounced filtering when the search text changes.
        .onChange(of: searchText) { newTerm in
            scheduleFilteringAndGrouping(term: newTerm, sourceOffers: offers)
        }
    }

    // MARK: - Data loading (network I/O remains unchanged)
    private func load() async {
        DispatchQueue.main.async {
            self.loading = true
            self.error = nil
        }
        do {
            // Network/Firestore calls may already run on background threads; keep as-is.
            let offs = try await offersRepo.listAll()
            let rests = try await restaurantsRepo.all()

            // Assign raw data on main and then trigger background processing.
            DispatchQueue.main.async {
                self.offers = offs
                self.restaurantsById = Dictionary(uniqueKeysWithValues: rests.map { ($0.id, $0) })
            }

            // After fetching, compute derived lists off-main.
            scheduleFilteringAndGrouping(term: searchText, sourceOffers: offs)
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
            }
        }
        DispatchQueue.main.async {
            self.loading = false
        }
    }

    // MARK: - GCD-backed filtering and grouping

    /// Schedules debounced filtering and grouping work on a background queue.
    /// - Note: Cancels any in-flight work to avoid racing/stale updates. Results are delivered on the main thread.
    private func scheduleFilteringAndGrouping(term: String, sourceOffers: [Offer]) {
        // Cancel previously scheduled work if any, to debounce rapid changes.
        pendingSearchWork?.cancel()

        // Capture immutable snapshots for background work to avoid reading @State concurrently.
        let snapshotTerm = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let snapshotOffers = sourceOffers

        let work = DispatchWorkItem {
            // Heavy work: filter and group off the main queue.
            let newFiltered: [Offer]
            if snapshotTerm.isEmpty {
                newFiltered = snapshotOffers
            } else {
                newFiltered = snapshotOffers.filter {
                    let hay = [
                        $0.title,
                        $0.description,
                        $0.tags.joined(separator: " ")
                    ].joined(separator: " ").lowercased()
                    return hay.contains(snapshotTerm)
                }
            }

            let newGrouped = Dictionary(grouping: newFiltered, by: { $0.restaurantId })

            // Deliver results to the UI on the main thread.
            DispatchQueue.main.async {
                self.filteredOffers = newFiltered
                self.groupedOffers = newGrouped
            }
        }

        // Keep a reference for potential cancellation and dispatch with a small debounce.
        pendingSearchWork = work
        // NOTE: Using DispatchTime.now() explicitly avoids parser quirks reported by some toolchains.
        filterQueue.asyncAfter(deadline: DispatchTime.now() + .milliseconds(200), execute: work)
    }
}

// MARK: - UI Section Header (unchanged)
private struct OffersSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.custom("Montserrat-Bold", size: 24))
            .foregroundStyle(Palette.purple)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}
