//
//  NewOfferView.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//


import SwiftUI
import FirebaseAuth

struct NewOfferView: View {
    var onCreated: (() -> Void)? = nil

    @State private var title = ""
    @State private var description = ""
    @State private var discount = "0"
    @State private var image = ""          // url o dataURL
    @State private var tagsText = ""       // "big,cheap"
    @State private var validFrom = Date()
    @State private var validTo   = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

    @State private var isSaving = false
    @State private var error: String?

    private let repo = OffersRepository()

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Title", text: $title)
                TextField("Description", text: $description, axis: .vertical)
                TextField("Discount %", text: $discount)
                    .keyboardType(.numberPad)
            }

            Section("Media") {
                TextField("Image URL or data:image/...base64", text: $image)
            }

            Section("Tags") {
                TextField("Comma separated (e.g., big,cheap)", text: $tagsText)
            }

            Section("Validity") {
                DatePicker("Valid from", selection: $validFrom, displayedComponents: [.date, .hourAndMinute])
                DatePicker("Valid to", selection: $validTo, displayedComponents: [.date, .hourAndMinute])
            }

            if let error {
                Text(error).foregroundColor(.red)
            }

            Button {
                Task { await save() }
            } label: {
                Text(isSaving ? "Creating..." : "Create Offer")
            }
            .disabled(isSaving || title.isEmpty || description.isEmpty || image.isEmpty)
        }
        .navigationTitle("New Offer")
    }

    private func save() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isSaving = true; error = nil
        do {
            try await repo.create(
                forRestaurantUid: uid,
                title: title,
                description: description,
                discountPercentage: Int(discount) ?? 0,
                image: image,
                tags: tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                validFrom: validFrom,
                validTo: validTo
            )
            isSaving = false
            onCreated?()
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }
}
