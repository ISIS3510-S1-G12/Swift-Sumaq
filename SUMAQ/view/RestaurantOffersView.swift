import SwiftUI
import FirebaseAuth

struct OffersContent: View {
    @State private var searchText: String = ""
    @State private var offers: [Offer] = []
    @State private var loading = true
    @State private var error: String?

    private let repo = OffersRepository()

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

    private func load() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        loading = true; error = nil
        do {
            offers = try await repo.listForRestaurant(uid: uid)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func reload() { Task { await load() } }
}

private struct SmallCapsuleButton: View {
    let title: String
    let background: Color
    let textColor: Color

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
