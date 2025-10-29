import Foundation

enum ScreenName {
    static let home              = "home"
    static let restaurantDetail  = "restaurant_detail"
    static let favorites         = "favorites"
    static let offers            = "offers"
    static let reviewHistory     = "review_history"
    static let login             = "login"
    static let register          = "register"
    static let userProfile       = "user_profile"
    static let restaurantProfile = "restaurant_profile"
    static let map               = "map"
    static let peopleNearby      = "people_nearby"
    static let addReview         = "add_review"
    static let newDish           = "new_dish"
    static let newOffer          = "new_offer"
}

// MARK: - Screen Categories
enum ScreenCategory {
    static let mainNavigation    = "main_navigation"    // home, map, favorites, offers
    static let restaurantDetail  = "restaurant_detail"  // restaurant detail views
    static let authentication    = "authentication"     // login, register
    static let userProfile       = "user_profile"       // user profile, settings
    static let contentCreation   = "content_creation"   // add review, new dish, new offer
    static let socialFeatures    = "social_features"    // people nearby, reviews
}

enum EventName {
    // Session Events
    static let sessionStart      = "session_start"
    static let sessionEnd        = "session_end"            // session_duration_seconds, total_session_time, unique_restaurants_visited
    static let sessionPause      = "session_pause"          // session_duration_seconds
    static let sessionResume     = "session_resume"
    
    // Screen Events
    static let screenStart       = "screen_start"           // screen
    static let screenEnd         = "screen_end"             // screen, screen_duration_seconds
    static let screenView        = "screen_view"            // screen_name
    
    // User Engagement
    static let userEngagement    = "user_engagement"        // action, custom_params
    static let userLogin         = "user_login"             // user_type
    static let userLogout        = "user_logout"            // user_type
    static let roleChange        = "role_change"            // new_role
    
    // App Events
    static let tabSelect         = "tab_select"             // screen, tab
    static let mapPinsLoaded     = "map_pins_loaded"        // count, load_ms
    static let restaurantOpen    = "restaurant_open"        // source, restaurant_id, restaurant_name
    static let restaurantVisit   = "restaurant_visit"       // restaurant_id, restaurant_name
    static let restaurantVisitSession = "restaurant_visit_session" // restaurant_id, restaurant_name, is_new_visit, unique_restaurants_in_session
    static let favoriteAdd       = "favorite_add"           // restaurant_id
    static let favoriteRemove    = "favorite_remove"        // restaurant_id
    static let peopleTapped      = "people_tap"             // screen
    static let reviewTap         = "review_tap"             // screen, restaurant_id
    static let locationAuth      = "location_permission"    // status, granted(bool)
    static let restaurantMarkedVisited = "restaurant_marked_visited" // restaurant_id
    
    // Legacy Events (keeping for compatibility)
    static let sessionStartCustom = "session_start_custom"
    static let sessionEndCustom  = "session_end_custom"     // duration_ms
}

// MARK: - Session Events
extension EventName {
    enum SessionEvents: String {
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
        case sessionPause = "session_pause"
        case sessionResume = "session_resume"
        case screenView = "screen_view"
        case userEngagement = "user_engagement"
        case userLogin = "user_login"
        case userLogout = "user_logout"
        case roleChange = "role_change"
    }
}

// MARK: - Screen Events
extension EventName {
    enum ScreenEvents: String {
        case screenStart = "screen_start"
        case screenEnd = "screen_end"
        case screenView = "screen_view"
        case tabSelect = "tab_select"
    }
}
