# SUMAQ App - Architecture Strategies Documentation

## Table of Contents
1. [Multithreading for Reviews Feature](#1-multithreading-for-reviews-feature)
2. [Local Storage for Reviews](#2-local-storage-for-reviews)
3. [Offline Login (Keychain)](#3-offline-login-keychain)
4. [Caching Strategies](#4-caching-strategies)
5. [Connectivity Protection for Views](#5-connectivity-protection-for-views)

---

## 1. Multithreading for Reviews Feature

### Overview
The reviews feature implements four distinct multithreading strategies to optimize performance, handle concurrent operations, and provide real-time updates.

### 1.1 Closures – Upload Progress for Images

**Where:** `SUMAQ/model/StorageService.swift` (lines 18-87), `SUMAQ/view/AddReviewView.swift` (lines 161-189), `SUMAQ/data/repositories/ReviewsRepository.swift` (lines 72-147)

**How:**
- Image upload uses Firebase Storage's progress observation mechanism
- Closure-based callbacks track upload progress in real-time
- Progress is calculated as `completedUnitCount / totalUnitCount`
- Progress closure is called on background thread and then dispatched to main thread for UI updates

```swift
// StorageService.swift - Lines 78-86
if let progress {
    task.observe(.progress) { snapshot in
        guard let total = snapshot.progress?.totalUnitCount,
              total > 0,
              let completed = snapshot.progress?.completedUnitCount else { return }
        let pct = Double(completed) / Double(total)
        progress(pct)
    }
}
```

**Why:**
- Provides real-time feedback to users during image upload
- Allows UI to update progress bar without blocking the main thread
- Improves user experience by showing upload status

**Applies to:**
- **Only users (NOT restaurants)**: 
  - Only users can create reviews (restaurants can only view reviews they receive)
  - `AddReviewView` is used exclusively by users when writing reviews
  - Restaurants don't have a review creation interface, so they don't need upload progress tracking

### 1.2 Grand Central Dispatch (GCD) – Parallel Data Loading

**Where:** `SUMAQ/view/ReviewHistoryUser.swift` (lines 160-219), `SUMAQ/view/UserRestaurantDetailView.swift` (lines 343-415)

**How:**
- Uses `DispatchGroup` to coordinate parallel data loading operations
- Multiple independent operations (user data, reviews data) are loaded concurrently on background queues
- Operations are dispatched to `DispatchQueue.global(qos: .userInitiated)` for parallel execution
- `DispatchGroup.enter()` and `leave()` track completion of async operations
- Results are synchronized using `group.notify()` callback

```swift
// ReviewHistoryUser.swift - Lines 160-196
let group = DispatchGroup()
var userResult: AppUser?
var reviewsResult: [Review] = []

// Load user and reviews in parallel
group.enter()
DispatchQueue.global(qos: .userInitiated).async {
    Task {
        do {
            userResult = try await self.usersRepo.getCurrentUser()
        } catch {
            userError = error
        }
        group.leave()
    }
}

group.enter()
DispatchQueue.global(qos: .userInitiated).async {
    Task {
        do {
            reviewsResult = try await self.reviewsRepo.listMyReviews()
        } catch {
            reviewsError = error
        }
        group.leave()
    }
}
```

**Why:**
- Significantly reduces loading time by running independent operations concurrently
- Improves app responsiveness by offloading work from main thread
- Better utilization of device resources (multiple CPU cores)

**Applies to:**
- **Both users AND restaurants (with different implementations)**: 
  - **Users**: `ReviewHistoryUser.swift` and `UserRestaurantDetailView.swift` use explicit GCD (`DispatchGroup`) to parallelize user data and reviews loading
  - **Restaurants**: `RestaurantReviewView.swift` uses modern Swift Concurrency (async/await) which inherently provides parallelism - loads reviews and user data sequentially but efficiently with structured concurrency
  - Both approaches achieve parallel data loading, but users use traditional GCD while restaurants use Swift's modern concurrency model

### 1.3 Swift Concurrency (async/await) – Controlled Batch Upload with TaskGroup

**Where:** `SUMAQ/data/repositories/ReviewsRepository.swift` (lines 317-415)

**How:**
- Implements `withThrowingTaskGroup` for controlled concurrent batch uploads
- Uses a queue-based approach with `maxConcurrent` limit (default: 3)
- Tasks are added to the group dynamically as previous tasks complete
- Progress callback reports completion count vs total count
- Each review creation runs in its own async task within the group

```swift
// ReviewsRepository.swift - Lines 337-389
try await withThrowingTaskGroup(of: Result<Void, Error>.self) { group in
    // Start initial batch of tasks
    for _ in 0..<min(maxConcurrent, reviewQueue.count) {
        if let review = reviewQueue.popFirst() {
            group.addTask {
                do {
                    try await self.createReview(
                        restaurantId: review.restaurantId,
                        stars: review.stars,
                        comment: review.comment,
                        imageData: review.imageData
                    )
                    return .success(())
                } catch {
                    return .failure(error)
                }
            }
        }
    }
    
    // Process results and add new tasks as they complete
    while let result = try await group.next() {
        completedCount += 1
        // Add next review if queue has more
        if let nextReview = reviewQueue.popFirst() {
            group.addTask { /* ... */ }
        }
    }
}
```

**Why:**
- Prevents overwhelming the network with too many concurrent uploads
- Provides controlled concurrency that respects network and device limitations
- Allows batch operations with progress tracking
- Better error handling per individual review vs entire batch

**Applies to:**
- **Only users (NOT restaurants)**: 
  - `createReviewsBatch()` in `ReviewsRepository.swift` is for creating multiple reviews at once
  - Only users can create reviews; restaurants only view reviews they receive
  - This is a power-user/testing feature that allows batch upload of multiple reviews
  - Restaurants don't need batch operations since they don't create reviews

### 1.4 Combine Framework – Real-time Reviews Streaming

**Where:** `SUMAQ/data/repositories/ReviewsRepository.swift` (lines 417-492), `SUMAQ/view/ReviewHistoryUser.swift` (lines 247-287), `SUMAQ/view/UserRestaurantDetailView.swift` (lines 496-538), `SUMAQ/view/RestaurantReviewView.swift` (lines 235-276)

**How:**
- Uses Firestore's `addSnapshotListener` to create real-time publishers
- Publisher emits arrays of reviews whenever Firestore collection changes
- Combine pipeline: `reviewsPublisher(for: restaurantId)` → `.receive(on: DispatchQueue.main)` → `.sink()`
- Subscriptions are managed with `AnyCancellable` and cancelled on view disappearance
- Publisher automatically handles connection state and error propagation

```swift
// ReviewsRepository.swift - Lines 423-452
func reviewsPublisher(for restaurantId: String) -> AnyPublisher<[Review], Error> {
    let subject = PassthroughSubject<[Review], Error>()
    
    let listener = db.collection(coll)
        .whereField("restaurant_id", isEqualTo: restaurantId)
        .order(by: "createdAt", descending: true)
        .addSnapshotListener { [weak subject] snapshot, error in
            if let error = error {
                subject?.send(completion: .failure(error))
            } else if let snapshot = snapshot {
                let items = snapshot.documents.compactMap { Review(doc: $0) }
                subject?.send(items)
            }
        }
    
    return subject
        .handleEvents(receiveCancel: {
            listener.remove()
        })
        .eraseToAnyPublisher()
}
```

```swift
// ReviewHistoryUser.swift - Lines 248-280
private func startRealTimeUpdates() {
    guard !isSubscribedToPublisher else { return }
    isSubscribedToPublisher = true
    
    reviewsCancellable = reviewsRepo.myReviewsPublisher()
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case .failure(let err) = completion {
                    if self.reviews.isEmpty {
                        self.error = err.localizedDescription
                    }
                }
            },
            receiveValue: { newReviews in
                self.reviews = newReviews
                // Update SQLite cache in background
                Task.detached { [localStore = self.localStore] in
                    for review in newReviews {
                        try? localStore.reviews.upsert(ReviewRecord(from: review))
                    }
                }
            }
        )
}
```

**Why:**
- Provides instant UI updates when reviews are added/modified by other users
- Eliminates need for polling or manual refresh
- Reactive programming model fits well with SwiftUI's state management
- Automatic resource cleanup when view disappears

**Applies to:**
- **Both users AND restaurants**: 
  - **Users**: 
    - `ReviewHistoryUser.swift` uses `myReviewsPublisher()` to stream current user's reviews in real-time
    - `UserRestaurantDetailView.swift` uses `reviewsPublisher(for: restaurantId)` to stream reviews for a specific restaurant
  - **Restaurants**: 
    - `RestaurantReviewView.swift` uses `reviewsPublisher(for: restaurantId)` to stream reviews they receive in real-time
  - Both user types benefit from instant updates when reviews are added/modified
  - Same `ReviewsRepository.reviewsPublisher()` and `myReviewsPublisher()` methods are shared by both user types

---

## 2. Local Storage for Reviews

### 2.1 SQLite Database Storage

**Where:** `SUMAQ/storage/Database.swift`, `SUMAQ/storage/Store.swift`, `SUMAQ/storage/DAO/ReviewsDAO.swift`, `SUMAQ/data/repositories/ReviewsRepository.swift`

**How:**
- SQLite database located at `LibraryDirectory/LocalDatabase/sumaq.sqlite`
- Uses WAL (Write-Ahead Logging) mode for better concurrency
- Database access is serialized via dedicated `DispatchQueue` (qos: .userInitiated)
- Reviews are stored in `Reviews` table with fields: id, userId, restaurantId, stars, comment, imageUrl, createdAt
- Offline-first strategy: queries SQLite first, then fetches from Firestore in background

**Applies to:**
- **Both users AND restaurants**: 
  - `ReviewsDAO.listForUser()` - stores/retrieves reviews for regular users
  - `ReviewsDAO.listForRestaurant()` - stores/retrieves reviews for restaurant owners
  - Both user and restaurant views use SQLite for offline access to reviews
  - Additionally, restaurants data is also stored in SQLite via `RestaurantsDAO` for offline browsing

```swift
// ReviewsRepository.swift - Lines 149-238 (listMyReviews)
func listMyReviews() async throws -> [Review] {
    let uid = try currentUid()
    
    // Offline-first: Try to read from SQLite first (fast, no loading)
    let localRecords = (try? local.reviews.listForUser(uid)) ?? []
    
    if !localRecords.isEmpty {
        // We have local data, return it immediately
        // and refresh from Firestore in background
        Task.detached { [weak self] in
            // Fetch from Firestore and update SQLite
            // ...
        }
        
        // Return local data immediately
        return localRecords.map { toReview(from: $0) }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }
    
    // No local data: fetch from Firestore
    // ... then save to SQLite
}
```

**Why:**
- Fast offline access to previously loaded reviews
- Works without internet connection
- Reduces network calls and improves perceived performance
- Data persistence across app restarts

### 2.2 Local File Storage for Review Images

**Where:** `SUMAQ/model/ReviewImageStore.swift`, `SUMAQ/view/LocalFileStore.swift`, `SUMAQ/data/repositories/ReviewsRepository.swift` (lines 46-70)

**How:**
- Images are saved to `DocumentsDirectory/my_reviews/{reviewId}.jpg`
- Images are only stored locally for current user's reviews (privacy consideration)
- Uses `LocalFileStore.shared.save()` for atomic file writes
- Images are downloaded asynchronously when review is loaded from Firestore
- Local image path is checked first before attempting remote download

```swift
// ReviewImageStore.swift
func saveImage(data: Data, reviewId: String) throws -> String {
    guard currentUserId() != nil else {
        throw NSError(domain: "ReviewImageStore", code: 401, 
                     userInfo: [NSLocalizedDescriptionKey: "No user session"])
    }
    
    let fileName = "\(reviewId).jpg"
    let localURL = try LocalFileStore.shared.save(
        data: data,
        fileName: fileName,
        subfolder: "my_reviews"
    )
    
    return localURL.path
}
```

```swift
// ReviewsRepository.swift - Lines 46-70
private func saveImageLocallyIfMine(imageURL: String, reviewId: String, reviewUserId: String) async {
    // Only save images for current user's reviews
    guard let currentUserId = Auth.auth().currentUser?.uid,
          reviewUserId == currentUserId,
          !imageURL.isEmpty,
          imageURL.hasPrefix("http") else {
        return
    }
    
    // Skip if already exists
    if ReviewImageStore.shared.hasLocalImage(reviewId: reviewId) {
        return
    }
    
    do {
        guard let url = URL(string: imageURL) else { return }
        let (data, _) = try await Self.imageSession.data(from: url)
        
        // Save locally (non-blocking, best-effort)
        try? ReviewImageStore.shared.saveImage(data: data, reviewId: reviewId)
    } catch {
        // Non-fatal: silently fail
    }
}
```

**Why:**
- Enables offline viewing of review images for user's own reviews
- Reduces bandwidth usage by caching images locally
- Faster image loading from local storage vs network
- Privacy: only stores images for current user's reviews

**Applies to:**
- **Only users (NOT restaurants)**: 
  - Local file storage for review images is intentionally limited to the current user's own reviews
  - Privacy consideration: restaurants viewing reviews do NOT get local image storage
  - Images are only saved locally when `reviewUserId == currentUserId` (see `ReviewsRepository.saveImageLocallyIfMine()`)
  - Restaurants can still view review images via remote URLs, but images are not cached locally

---

## 3. Offline Login (Keychain)

**Where:** `SUMAQ/model/KeychainHelper.swift`, `SUMAQ/view/LoginView.swift` (lines 91-170)

**How:**
- Uses iOS Keychain Services (Security framework) for secure credential storage
- Stores two types of data:
  1. Last login email (for convenience)
  2. Offline credentials (email, password, uid, role) - encrypted and device-only accessible
- Keychain items use `kSecClassGenericPassword` with service identifier `"com.sumaq.app"`
- Offline credentials are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for security
- On login attempt without internet, app compares entered credentials with saved Keychain data

```swift
// KeychainHelper.swift - Lines 76-93
func saveOfflineCredentials(email: String, password: String, uid: String, role: String) {
    let credentials = OfflineCredentials(email: email, password: password, uid: uid, role: role)
    
    guard let data = try? JSONEncoder().encode(credentials) else { return }
    
    deleteOfflineCredentials()
    
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: credentialsKey,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    
    SecItemAdd(query as CFDictionary, nil)
}
```

```swift
// LoginView.swift - Lines 91-131
private func doLogin() {
    // Check network connectivity
    if !NetworkHelper.shared.isConnectedToNetwork() {
        // No internet connection - try offline login
        if let savedCredentials = KeychainHelper.shared.getOfflineCredentials(),
           savedCredentials.email.lowercased() == user.lowercased() &&
           savedCredentials.password == pass {
            // Credentials match saved offline credentials - proceed with offline login
            loginOffline { result in
                // Handle offline login result
            }
            return
        } else {
            // Show offline notice
            showOfflineNotice = true
            return
        }
    }
    // Has internet - proceed with normal login
}
```

**Why:**
- Allows users to access the app even when offline (limited functionality)
- Provides seamless login experience by pre-filling email
- Secure storage using iOS Keychain (encrypted, protected by device lock)
- Device-only access prevents credential sync across devices (security)

**Applies to:**
- **Both users AND restaurants**: 
  - Keychain stores credentials with a `role` field: `"user"` or `"restaurant"` (see `OfflineCredentials` struct)
  - `LoginView` accepts `role: UserType` parameter that works for both user types
  - Offline login supports both destinations: `.userHome` and `.restaurantHome`
  - Same Keychain service (`"com.sumaq.app"`) is used for both, differentiated by role

---

## 4. Caching Strategies

### 4.1 LRU Cache for Images (General Image Caching)

**Purpose:** Caches all images throughout the app (restaurant images, offer images, review images, user avatars, etc.)

**Where:** `SUMAQ/data/cache/memory/LRUCache.swift`, `SUMAQ/data/cache/memory/ImageCache.swift`, `SUMAQ/view/RemoteImage.swift`, `SUMAQ/view/RestaurantCard.swift`, `SUMAQ/view/OfferCard.swift`, `SUMAQ/view/ReviewCard.swift`

**How:**
- Custom `LRUCache` implementation using doubly-linked list for O(1) operations
- `ImageCache` wraps `LRUCache<String, UIImage>` with image-specific optimizations
- Cache limits: 300 items max, 64MB total cost
- Image downsampling: reduces image size to max 900px dimension before caching
- Thread-safe using `NSLock` for concurrent access
- Eviction: removes least recently used items when limits are exceeded

```swift
// LRUCache.swift - Lines 10-104
public final class LRUCache<Key: Hashable, Value> {
    private let lock = NSLock()
    private var dict: [Key: Node] = [:]
    private var head: Node? // MRU (Most Recently Used)
    private var tail: Node? // LRU (Least Recently Used)
    private var totalCost = 0
    
    private let countLimit: Int
    private let costLimit: Int
    
    public init(countLimit: Int = 300, costLimit: Int = 64 * 1024 * 1024) {
        self.countLimit = countLimit
        self.costLimit = costLimit
    }
    
    private func evictIfNeeded() {
        while (dict.count > countLimit || totalCost > costLimit), let lru = tail {
            dict.removeValue(forKey: lru.key)
            totalCost -= lru.cost
            removeNode(lru)
        }
    }
}
```

```swift
// ImageCache.swift - Lines 12-58
final class ImageCache {
    static let shared = ImageCache(countLimit: 300, costLimit: 64 * 1024 * 1024)
    
    private let lru: LRUCache<String, UIImage>
    
    func downsampled(from data: Data,
                     hintUTI: CFString = kUTTypeJPEG,
                     maxDimension: CGFloat = 900) -> UIImage? {
        // Creates thumbnail with max 900px dimension to save memory
        // ...
    }
}
```

**What it's used for:**
- **All images in the app**: Restaurant images, offer images, review images, user avatars, dish images
- Used universally via `RemoteImage` component which checks `ImageCache.shared` before downloading
- Applied automatically to any image loaded through `RemoteImage` (offer cards, restaurant cards, review cards, etc.)

**Applies to:**
- **Both users AND restaurants**: 
  - **Users**: `RestaurantCard`, `OfferCard`, `ReviewCard`, `TopBar`, `UserRestaurantDishCard` - all use `RemoteImage` which uses LRU cache
  - **Restaurants**: `RestaurantDishCard`, `RestaurantTopBar` - restaurant views also use `RemoteImage` which uses LRU cache
  - Any view that displays images through `RemoteImage` benefits from LRU caching, regardless of user type

**Why:**
- Dramatically improves image loading performance (instant for cached images)
- Reduces network bandwidth usage
- Memory-efficient eviction prevents excessive RAM usage
- LRU strategy keeps frequently accessed images in cache

### 4.2 NSCache for User Basic Data (Reviews Feature)

**Purpose:** Caches user basic information (names and avatar URLs) to avoid repeated network calls when displaying reviews

**Where:** `SUMAQ/data/cache/memory/UserBasicDataCache.swift`, `SUMAQ/view/UserRestaurantDetailView.swift` (lines 427-465), `SUMAQ/view/RestaurantReviewView.swift` (lines 194-232)

**How:**
- Uses Foundation's `NSCache<NSString, UserBasicDataWrapper>` for user basic data (names, avatar URLs)
- Cache limits: 200 users max, 2MB total cost
- Automatically evicts entries under memory pressure (iOS system integration)
- Wrapper class `UserBasicDataWrapper` extends `NSObject` (NSCache requirement)
- Cost estimation: ~200 bytes per user entry

```swift
// UserBasicDataCache.swift - Lines 30-109
final class UserBasicDataCache {
    static let shared = UserBasicDataCache()
    
    private let cache = NSCache<NSString, UserBasicDataWrapper>()
    
    private let countLimit = 200
    private let costLimit = 1024 * 1024 * 2  // 2MB
    
    private init() {
        cache.countLimit = countLimit
        cache.totalCostLimit = costLimit
        cache.name = "UserBasicDataCache"
    }
    
    func getUserData(userId: String) -> UserBasicData? {
        return cache.object(forKey: userId as NSString)?.data
    }
    
    func setUserData(_ data: UserBasicData) {
        let wrapper = UserBasicDataWrapper(data: data)
        cache.setObject(wrapper, forKey: data.userId as NSString, cost: 200)
    }
}
```

**Where used in reviews:**
- `UserRestaurantDetailView.loadUserDataForReviews()` - Lines 427-465
- `RestaurantReviewView.loadUserData()` - Lines 194-232
- Both check cache first before fetching from network

```swift
// UserRestaurantDetailView.swift - Lines 427-445
private func loadUserDataForReviews(_ reviewsToLoad: [Review]) async {
    let userIds = Array(Set(reviewsToLoad.map { $0.userId }))
    
    // Check cache first for immediate display
    let cache = UserBasicDataCache.shared
    let cachedData = cache.getUsersData(userIds: userIds)
    
    if !cachedData.isEmpty {
        var names: [String: String] = [:]
        var avatars: [String: String] = [:]
        for (userId, data) in cachedData {
            names[userId] = data.name
            if let url = data.avatarURL, !url.isEmpty {
                avatars[userId] = url
            }
        }
        // Update UI immediately with cached data
        await MainActor.run {
            self.userNamesById.merge(names) { _, new in new }
            self.userAvatarsById.merge(avatars) { _, new in new }
        }
    }
    
    // Fetch fresh data in background
    // ...
}
```

**What it's used for:**
- **User basic data for reviews**: Caches user names and avatar URLs needed to display review author information
- Used in review display views (`UserRestaurantDetailView`, `RestaurantReviewView`, `ReviewHistoryUser`)
- Avoids fetching the same user's data multiple times when displaying multiple reviews from the same user
- Note: Also used in `RestaurantOffersView` for caching offers, but primarily designed for reviews user data

**Applies to:**
- **Both users AND restaurants**: 
  - **Users**: `UserRestaurantDetailView` uses `UserBasicDataCache` to cache user data when viewing restaurant reviews
  - **Restaurants**: `RestaurantReviewView` uses `UserBasicDataCache` to cache user data when viewing reviews they received
  - Both user types benefit from cached user data (names, avatars) when displaying reviews, avoiding redundant network calls

**Why:**
- Reduces redundant network calls for user data (names, avatars)
- Provides instant UI updates when user data is already cached
- Automatic memory management via NSCache integration with iOS (evicts under memory pressure)
- Significant performance improvement when displaying multiple reviews with same users (same user appears in multiple reviews)

---

## 5. Connectivity Protection for Views

### 5.1 Review History (User Side)

**Where:** `SUMAQ/view/ReviewHistoryUser.swift` (lines 23-245)

**How:**
- Network connectivity check using `NetworkHelper.shared.isConnectedToNetwork()`
- Displays specific offline message when no internet: "No internet connection" with wifi.slash icon
- Shows helpful message: "We couldn't load your reviews. Please check your internet connection and try again."
- Still displays cached SQLite data when available (offline-first approach)
- Loading message indicates offline support: "If you are having a slow connection or if you are offline, we will show you your saved reviews in a moment."

```swift
// ReviewHistoryUser.swift - Lines 60-83
} else if let error {
    VStack(spacing: 12) {
        if !hasInternetConnection {
            Image(systemName: "wifi.slash")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No internet connection")
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundStyle(.primary)
            Text("We couldn't load your reviews. Please check your internet connection and try again.")
                .font(.custom("Montserrat-Regular", size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        } else {
            Text(error)
                // ... regular error display
        }
    }
}
```

**Connectivity check:**
```swift
// ReviewHistoryUser.swift - Lines 235-244
private func checkInternetConnection() {
    // Use simple synchronous check for immediate UI update
    hasInternetConnection = NetworkHelper.shared.isConnectedToNetwork()
    
    // Also use async check for more accurate result
    NetworkHelper.shared.checkNetworkConnection { isConnected in
        Task { @MainActor in
            self.hasInternetConnection = isConnected
        }
    }
}
```

**Why:**
- Provides clear feedback to users about connectivity issues
- Maintains functionality with cached data when offline
- Prevents user frustration by explaining the situation clearly

### 5.2 Review History (Restaurant Side)

**Where:** `SUMAQ/view/RestaurantReviewView.swift` (lines 20-289)

**How:**
- Similar implementation to user-side review history
- Checks connectivity using `NetworkHelper.shared.isConnectedToNetwork()`
- Displays offline message: "No internet connection" with same UI pattern
- Shows loading message: "If you are having a slow connection or if you are offline, we will show you the saved reviews in a moment."
- Loads from SQLite first (offline-first), then refreshes from Firestore

```swift
// RestaurantReviewView.swift - Lines 57-79
} else if let error {
    VStack(spacing: 12) {
        if !hasInternetConnection {
            Image(systemName: "wifi.slash")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No internet connection")
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundStyle(.primary)
            Text("We couldn't load the reviews. Please check your internet connection and try again.")
                .font(.custom("Montserrat-Regular", size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        } else {
            // Regular error display
        }
    }
}
```

**Connectivity check:**
```swift
// RestaurantReviewView.swift - Lines 121-132
private func checkInternetConnection() {
    hasInternetConnection = NetworkHelper.shared.isConnectedToNetwork()
    
    NetworkHelper.shared.checkNetworkConnection { isConnected in
        Task { @MainActor in
            if self.hasInternetConnection != isConnected {
                self.hasInternetConnection = isConnected
            }
        }
    }
}
```

**Why:**
- Consistent user experience across user and restaurant views
- Enables restaurants to view their reviews even when offline
- Clear communication about connectivity status

### 5.3 Reviews Detail (User Side - Restaurant Detail View)

**Where:** `SUMAQ/view/UserRestaurantDetailView.swift` (lines 20-538)

**How:**
- Separate connectivity state for reviews tab: `hasInternetConnectionReviews`
- Connectivity checked on view appear (only once)
- Displays offline message in `ReviewsTab` component
- Offline-first loading: SQLite first, then Firestore refresh
- Real-time updates disabled when offline (Combine subscription cancelled)

```swift
// UserRestaurantDetailView.swift - Lines 690-733 (ReviewsTab)
private struct ReviewsTab: View {
    // ...
    let hasInternetConnection: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            if loading {
                ProgressView().padding()
                Text("Loading Reviews…")
                Text("If you are having a slow connection or if you are offline, we will show you the saved reviews in a moment.")
            } else if let error {
                VStack(spacing: 12) {
                    if !hasInternetConnection {
                        Image(systemName: "wifi.slash")
                        Text("No internet connection")
                        Text("We couldn't load the reviews. Please check your internet connection and try again.")
                    } else {
                        Text(error)
                    }
                }
            }
            // ... review cards
        }
    }
}
```

**Connectivity check:**
```swift
// UserRestaurantDetailView.swift - Lines 481-494
private func checkInternetConnectionReviews() {
    hasInternetConnectionReviews = NetworkHelper.shared.isConnectedToNetwork()
    
    NetworkHelper.shared.checkNetworkConnection { isConnected in
        Task { @MainActor in
            if self.hasInternetConnectionReviews != isConnected {
                self.hasInternetConnectionReviews = isConnected
            }
        }
    }
}
```

**Why:**
- Granular connectivity handling per tab (reviews vs menu vs offers)
- Allows viewing restaurant details including reviews when offline
- Maintains app usability in poor network conditions

### 5.4 "Do a Review" Button Protection

**Where:** `SUMAQ/view/UserRestaurantDetailView.swift` (lines 172-212), `SUMAQ/view/AddReviewView.swift`

**How:**
- Button tap checks connectivity before navigating to `AddReviewView`
- If offline, shows alert instead of navigating
- Alert message: "No internet connection" with detailed explanation
- Button remains enabled but action is prevented

```swift
// UserRestaurantDetailView.swift - Lines 172-212
Button {
    // Check internet connection before navigating
    if NetworkHelper.shared.isConnectedToNetwork() {
        showAddReview = true
        AnalyticsService.shared.log(EventName.reviewTap, [
            "screen": ScreenName.restaurantDetail,
            "restaurant_id": restaurant.id
        ])
    } else {
        showOfflineAlert = true
    }
} label: {
    HStack(spacing: 8) {
        Image(systemName: "square.and.pencil")
        Text("Do a review")
    }
    // ... styling
}
.alert("No internet connection", isPresented: $showOfflineAlert) {
    Button("OK", role: .cancel) { }
} message: {
    Text("We know your opinion is important, but please try again when you have an internet connection. Reviews need to be uploaded to be saved.")
}
```

**Why:**
- Prevents user frustration by blocking review creation when offline
- Clear explanation that reviews require internet connection
- Avoids creating incomplete review data that can't be saved
- User-friendly messaging acknowledges the importance of their feedback

---

## Summary

The SUMAQ app implements a comprehensive architecture with:

1. **Multithreading**: Four strategies (closures, GCD, async/await TaskGroup, Combine) for optimal performance
2. **Local Storage**: SQLite for review data, local files for images - enabling full offline functionality
3. **Offline Login**: Keychain-secured credential storage for offline access
4. **Caching**: LRU for images/offers, NSCache for user data - reducing network calls and improving performance
5. **Connectivity Protection**: All four review-related views handle offline scenarios gracefully with clear user messaging

These strategies work together to create a robust, performant, and user-friendly mobile application that functions well even in poor network conditions.

