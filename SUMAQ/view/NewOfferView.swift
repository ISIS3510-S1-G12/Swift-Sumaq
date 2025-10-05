import SwiftUI
import PhotosUI
import FirebaseAuth

struct NewOfferView: View {
    var onCreated: (() -> Void)? = nil

    @State private var title = ""
    @State private var description = ""
    @State private var discount = "0"
    @State private var price = ""
    @State private var tagsText = ""
    @State private var validFrom = Date()
    @State private var validTo   = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

    @State private var imageData: Data? = nil
    @State private var photoItem: PhotosPickerItem? = nil

    @State private var isSaving = false
    @State private var error: String?

    private let repo = OffersRepository()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabeledField(title: "Title",
                             text: $title,
                             placeholder: "Title",
                             keyboard: .default,
                             autocap: .words,
                             labelColor: Palette.teal)

                LabeledTextArea(title: "Description",
                                text: $description,
                                placeholder: "Write the description here",
                                labelColor: Palette.teal)

                HStack(spacing: 12) {
                    LabeledField(title: "Discount %",
                                 text: $discount,
                                 placeholder: "0",
                                 keyboard: .numberPad,
                                 labelColor: Palette.teal)
                    LabeledField(title: "Price",
                                 text: $price,
                                 placeholder: "0",
                                 keyboard: .numberPad,
                                 labelColor: Palette.teal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Image")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(Palette.teal)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack {
                            if let imageData, let ui = UIImage(data: imageData) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 140)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Pick an image")
                                }
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(Palette.grayLight)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onChange(of: photoItem) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self) {

                                if let ui = UIImage(data: data), let jpeg = ui.jpegData(compressionQuality: 0.9) {
                                    await MainActor.run { self.imageData = jpeg }
                                } else {
                                    await MainActor.run { self.imageData = data }
                                }
                            } else {
                                await MainActor.run { self.error = "Could not load image from library." }
                            }
                        }
                    }
                }

                LabeledField(title: "Tags",
                             text: $tagsText,
                             placeholder: "big, cheap",
                             keyboard: .default,
                             labelColor: Palette.teal)

                LabeledDatePickerField(title: "Valid from", date: $validFrom, labelColor: Palette.teal)
                LabeledDatePickerField(title: "Valid to",   date: $validTo,   labelColor: Palette.teal)

                if let error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, 4)
                }

                Button {
                    Task { await save() }
                } label: {
                    Text(isSaving ? "Creating..." : "Submit")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(PrimaryCapsuleButton(color: Palette.teal))
                .disabled(isSaving || title.isEmpty || description.isEmpty || imageData == nil)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("New Offer")
    }

    private func save() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let imageData else { error = "Pick an image"; return }
        isSaving = true; error = nil
        do {
            try await repo.create(
                forRestaurantUid: uid,
                title: title,
                description: description,
                discountPercentage: Int(discount) ?? 0,
                price: Int(price) ?? 0,
                imageData: imageData,
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

private struct LabeledTextArea: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var height: CGFloat = 110
    var labelColor: Color = Palette.teal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(labelColor)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.custom("Montserrat-Regular", size: 16))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $text)
                    .font(.custom("Montserrat-Regular", size: 16))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: height, alignment: .topLeading)
            }
            .background(Palette.grayLight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct LabeledDatePickerField: View {
    let title: String
    @Binding var date: Date
    var labelColor: Color = Palette.teal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(labelColor)

            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 12)
                .background(Palette.grayLight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
