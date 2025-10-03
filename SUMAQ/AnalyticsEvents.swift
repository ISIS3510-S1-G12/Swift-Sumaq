import Foundation

enum ScreenName {
    static let home              = "home"
    static let restaurantDetail  = "restaurant_detail"
}

enum EventName {
    static let sessionStart      = "session_start_custom"
    static let sessionEnd        = "session_end_custom"      // duration_ms
    static let screenStart       = "screen_start"            // screen
    static let screenEnd         = "screen_end"              // screen, duration_ms
    static let tabSelect         = "tab_select"              // screen, tab
    static let mapPinsLoaded     = "map_pins_loaded"         // count, load_ms
    static let restaurantOpen    = "restaurant_open"         // source, restaurant_id, restaurant_name
    static let restaurantVisit   = "restaurant_visit"        // restaurant_id, restaurant_name
    static let favoriteAdd       = "favorite_add"            // restaurant_id
    static let favoriteRemove    = "favorite_remove"         // restaurant_id
    static let peopleTapped      = "people_tap"              // screen
    static let reviewTap         = "review_tap"              // screen, restaurant_id
    static let locationAuth      = "location_permission"     // status, granted(bool)
}
