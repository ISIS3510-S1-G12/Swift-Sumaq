import Foundation
import FirebaseFirestore   // Para Timestamp

// model
struct Review: Identifiable, Hashable {
    let id: String
    let userId: String
    let restaurantId: String
    let authorUsername: String
    let rating: Double
    let comment: String
    let createdAt: Date
    let photoURL: URL?          // URL pública (si usas Storage)
    let photoBase64: String?    // Miniatura inline (si usas versión sin Storage)
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
        if let photoBase64 { data["photoBase64"] = photoBase64 }
        return data
    }

    // read from Firestore
    static func fromFirestore(id: String, _ dict: [String: Any]) -> Review? {
        // Enlaces opcionales válidos para guard
        guard
            let userId = dict["user_id"] as? String ?? (dict["user_id"] as? NSObject)?.description,
            let restaurantId = dict["restaurant_id"] as? String ?? (dict["restaurant_id"] as? NSObject)?.description,
            let rating = (dict["stars"] as? Double) ?? (dict["stars"] as? NSNumber)?.doubleValue,
            let comment = dict["comment"] as? String
        else { return nil }

        // authorUsername puede venir en distintas llaves; si no existe, lo dejamos en "".
        let authorUsername =
            (dict["author_username"] as? String) ??
            (dict["author"] as? String) ??
            ""

        // createdAt puede ser Date, Timestamp o venir nil la primera vez (serverTimestamp)
        let createdAt: Date =
            (dict["createdAt"] as? Date) ??
            (dict["createdAt"] as? Timestamp)?.dateValue() ??
            Date()

        // Campos opcionales de imagen
        let photoURL = (dict["photoURL"] as? String).flatMap(URL.init(string:))
        let photoBase64 = dict["photoBase64"] as? String

        return Review(
            id: id,
            userId: userId,
            restaurantId: restaurantId,
            authorUsername: authorUsername,
            rating: rating,
            comment: comment,
            createdAt: createdAt,
            photoURL: photoURL,
            photoBase64: photoBase64
        )
    }
}
