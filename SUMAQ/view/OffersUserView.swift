//
//  OffersUserView.swift
//  SUMAQ
//
//  Strategy #2 — GCD (DispatchQueue)  +  Strategy #5 — Combine

//  What (GCD):
//  - Offload CPU bound filtering (text match) and grouping (Dictionary(grouping:))
//    to a background queue. Results are delivered back on the main queue before
//    mutating @State.
//
//  Where off-main (GCD):
//  - `filterQueue` (QoS .userInitiated, concurrent) executes heavy work.
//  - `scheduleFilteringAndGrouping(...)` builds `newFiltered` and `newGrouped` on
//    `filterQueue`, then hops to main with `DispatchQueue.main.async`.
//
//  Hop back to main (GCD):
//  - Inside `scheduleFilteringAndGrouping(...)`, the assignments to
//    `filteredOffers` and `groupedOffers` are done on the main thread.
//
//  Debounce/cancellation (GCD):
//  - A `DispatchWorkItem` is used to cancel any in-flight computation when the
//    user keeps typing, avoiding stale results.
//
//  What (Combine):
//  - Debounce and coalesce search input events reactively.
//  - A `PassthroughSubject<String, Never>` receives raw search text changes,
//    then a Combine pipeline `.debounce` + `.removeDuplicates` triggers the
//    background GCD computation only after the user pauses typing.
//
//  Where (Combine):
//  - `searchSubject` and `searchCancellable` fields (see "Combine infrastructure").
//  - `.onAppear` sets up the Combine pipeline.
//  - `.onChange(of: searchText)` publishes each keystroke into `searchSubject`.
//  - When the debounced value arrives in `.sink`, we call
//    `scheduleFilteringAndGrouping(...)` (GCD) to do the heavy work off-main.
//
//  Important note about captures in SwiftUI Views:
//  - SwiftUI views are `struct`s (value types). Using `[weak self]` is invalid here
//    and causes the compiler error “weak may only be applied to class and class-bound
//    protocol types”. This file intentionally **does not** use `[weak self]` in the
//    Combine `.sink` closure. There is no retain cycle because:
//      (1) `OffersUserView` is a value type,
//      (2) The `AnyCancellable` is stored in `@State`, and
//      (3) SwiftUI will recreate the view as needed.
//    We still avoid long-lived background work by cancelling the `DispatchWorkItem`
//    on `onDisappear`.
//

//

import SwiftUI
import Combine // (Strategy #5 — Combine)

struct OffersUserView: View {
    var embedded: Bool = false

    // MARK: - UI State
    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionOffersView? = nil
    @State private var selectedTab = 2

    // Raw data loaded from repositories
    @State private var offers: [Offer] = []
    @State private var restaurantsById: [String: Restaurant] = [:]

    // Derived data backed by state (filled via GCD background work)
    @State private var filteredOffers: [Offer] = []
    @State private var groupedOffers: [String: [Offer]] = [:]

    @State private var loading = true
    @State private var error: String?

    private let offersRepo = OffersRepository()
    private let restaurantsRepo = RestaurantsRepository()

    // Screen tracking
    @State private var screenStartTime: Date?

    // MARK: - Concurrency (GCD) — Strategy #2
    private let filterQueue = DispatchQueue(label: "offers.filter.queue",
                                            qos: .userInitiated,
                                            attributes: .concurrent)
    @State private var pendingSearchWork: DispatchWorkItem?

    // MARK: - Combine — Strategy #5
    @State private var searchSubject = PassthroughSubject<String, Never>()
    @State private var searchCancellable: AnyCancellable?

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

            // (Strategy #5 — Combine) Build the debounced search pipeline once.
            if searchCancellable == nil {
                searchCancellable = searchSubject
                    .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main) // Wait for user to pause typing
                    .removeDuplicates() // Avoid recomputing for the same term
                    .sink { term in
                        // Call the GCD-backed heavy work with the current offers snapshot.
                        scheduleFilteringAndGrouping(term: term, sourceOffers: offers)
                    }
            }

            // Recompute derived data once (e.g., when returning to the screen).
            scheduleFilteringAndGrouping(term: searchText, sourceOffers: offers)

            // Seed the pipeline with the current searchText value.
            searchSubject.send(searchText)
        }
        .onDisappear {
            if let startTime = screenStartTime {
                let duration = Date().timeIntervalSince(startTime)
                SessionTracker.shared.trackScreenEnd(ScreenName.offers,
                                                     duration: duration,
                                                     category: ScreenCategory.mainNavigation)
            }
            // (Strategy #2 — GCD) Cancel any pending background work when leaving the screen to avoid wasted CPU.
            pendingSearchWork?.cancel()
            // (Strategy #5 — Combine) Stop listening for search changes.
            searchCancellable?.cancel()
            searchCancellable = nil
        }
        // Async network load is kept as-is; the GCD strategy applies to post-fetch transformations only.
        .task { await load() }
        // (Strategy #5 — Combine) Publish every keystroke to the Combine pipeline; the pipeline
        // will handle debounce and call the GCD-based computation at the right time.
        .onChange(of: searchText) { newTerm in
            searchSubject.send(newTerm)
        }
    }

    // MARK: - Data loading (network I/O remains unchanged)
    private func load() async {
        DispatchQueue.main.async {
            self.loading = true
            self.error = nil
        }
        do {
            let offs = try await offersRepo.listAll()
            let rests = try await restaurantsRepo.all()

            DispatchQueue.main.async {
                self.offers = offs
                self.restaurantsById = Dictionary(uniqueKeysWithValues: rests.map { ($0.id, $0) })
            }

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

    // MARK: - GCD-backed filtering and grouping  (Strategy #2)
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
