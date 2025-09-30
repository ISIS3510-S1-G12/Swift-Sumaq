import Foundation
import FirebaseFirestore   

// model
struct Review: Identifiable, Hashable {
    let id: String
    let userId: String
    let restaurantId: String
    let authorUsername: String
    let rating: Double
    let comment: String
    let createdAt: Date
    let photoURL: URL?        // public URL in Storage
}

extension Review {
    // write to Firestore
    var asFirestore: [String: Any] {
        var data: [String: Any] = [
            "user_id": userId,
            "restaurant_id": restaurantId,
            "author_username": authorUsername,
            "stars": rating,
            "comment": comment,
            "createdAt": createdAt
        ]
        if let photoURL { data["photoURL"] = photoURL.absoluteString }
        return data
    }

    // read from Firestore
    static func fromFirestore(id: String, _ dict: [String: Any]) -> Review? {

        guard
            let userId = dict["user_id"] as? String ?? (dict["user_id"] as? NSObject)?.description,
            let restaurantId = dict["restaurant_id"] as? String ?? (dict["restaurant_id"] as? NSObject)?.description,
            let authorUsername = dict["author_username"] as? String ?? dict["author"] as? String ?? "",
            let rating = (dict["stars"] as? Double) ?? (dict["stars"] as? NSNumber)?.doubleValue,
            let comment = dict["comment"] as? String
        else { return nil }

        let createdAt: Date =
            (dict["createdAt"] as? Date) ??
            (dict["createdAt"] as? Timestamp)?.dateValue() ??
            Date() 

        // photoURL optional
        let photoURL: URL?
        if let s = dict["photoURL"] as? String {
            photoURL = URL(string: s)
        } else {
            photoURL = nil
        }

        return Review(
            id: id,
            userId: userId,
            restaurantId: restaurantId,
            authorUsername: authorUsername,
            rating: rating,
            comment: comment,
            createdAt: createdAt,
            photoURL: photoURL
        )
    }
}
