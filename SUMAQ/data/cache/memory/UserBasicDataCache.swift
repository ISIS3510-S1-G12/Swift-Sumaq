//
//  UserBasicDataCache.swift
//  SUMAQ
//
//  Created on review feature optimization.
//  NSCache for user basic data (names and avatar URLs) to reduce repeated network calls.
//

import Foundation

/// Represents basic user data cached in memory
struct UserBasicData {
    let userId: String
    let name: String
    let avatarURL: String?
    
    init(userId: String, name: String, avatarURL: String?) {
        self.userId = userId
        self.name = name
        self.avatarURL = avatarURL
    }
    
    init(from appUser: AppUser) {
        self.userId = appUser.id
        self.name = appUser.name
        self.avatarURL = appUser.profilePictureURL
    }
}

/// NSCache for user basic data (names and avatar URLs)
/// Automatically evicts under memory pressure
final class UserBasicDataCache {
    static let shared = UserBasicDataCache()
    
    private let cache = NSCache<NSString, UserBasicDataWrapper>()
    
    // Cache limits
    private let countLimit = 200  // Maximum number of users to cache
    private let costLimit = 1024 * 1024 * 2  // 2MB limit (each entry is small ~100 bytes)
    
    private init() {
        cache.countLimit = countLimit
        cache.totalCostLimit = costLimit
        cache.name = "UserBasicDataCache"
    }
    
    /// Get user basic data from cache
    /// - Parameter userId: The user ID to look up
    /// - Returns: Cached user data if available, nil otherwise
    func getUserData(userId: String) -> UserBasicData? {
        return cache.object(forKey: userId as NSString)?.data
    }
    
    /// Get multiple user data entries from cache
    /// - Parameter userIds: Array of user IDs to look up
    /// - Returns: Dictionary mapping userId to cached data (only for found entries)
    func getUsersData(userIds: [String]) -> [String: UserBasicData] {
        var result: [String: UserBasicData] = [:]
        for userId in userIds {
            if let data = getUserData(userId: userId) {
                result[userId] = data
            }
        }
        return result
    }
    
    /// Store user basic data in cache
    /// - Parameter data: The user basic data to cache
    func setUserData(_ data: UserBasicData) {
        let wrapper = UserBasicDataWrapper(data: data)
        // Estimate cost: userId (~20 bytes) + name (~50 bytes) + avatarURL (~100 bytes) = ~170 bytes
        // Round up to 200 bytes for safety
        cache.setObject(wrapper, forKey: data.userId as NSString, cost: 200)
    }
    
    /// Store multiple user data entries in cache
    /// - Parameter usersData: Array of user data to cache
    func setUsersData(_ usersData: [UserBasicData]) {
        for data in usersData {
            setUserData(data)
        }
    }
    
    /// Store user data from AppUser array (convenience method)
    /// - Parameter appUsers: Array of AppUser to cache
    func setAppUsers(_ appUsers: [AppUser]) {
        let usersData = appUsers.map { UserBasicData(from: $0) }
        setUsersData(usersData)
    }
    
    /// Remove user data from cache
    /// - Parameter userId: The user ID to remove
    func removeUser(userId: String) {
        cache.removeObject(forKey: userId as NSString)
    }
    
    /// Clear all cached user data
    func removeAll() {
        cache.removeAllObjects()
    }
    
    /// Invalidate cache for specific users (useful when user data is updated)
    /// - Parameter userIds: Array of user IDs to invalidate
    func invalidateUsers(userIds: [String]) {
        for userId in userIds {
            removeUser(userId: userId)
        }
    }
}

// MARK: - Wrapper class for NSCache (NSCache requires NSObject)
private final class UserBasicDataWrapper: NSObject {
    let data: UserBasicData
    
    init(data: UserBasicData) {
        self.data = data
        super.init()
    }
}

