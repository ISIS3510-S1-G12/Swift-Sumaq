import SwiftUI
import Combine
import PhotosUI     // NUEVO

struct RegisterView: View {
    let role: UserType
    @StateObject private var controller = AuthController()

    // AUTH / comunes
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    // USER
    @State private var budget: String = ""
    @State private var diet: String = ""
    // NUEVO: imagen de usuario
    @State private var userPhotoItem: PhotosPickerItem?
    @State private var userPhotoData: Data?

    // RESTAURANT
    @State private var address: String = ""
    @State private var openingTime: String = ""
    @State private var closingTime: String = ""
    @State private var restaurantType: String = ""
    @State private var busiestHoursText: String = ""
    @State private var offer: Bool = false
    @State private var ratingText: String = ""
    // NUEVO: imagen de restaurante
    @State private var restPhotoItem: PhotosPickerItem?
    @State private var restPhotoData: Data?

    private var accentColor: Color { role == .user ? Palette.purple : Palette.teal }
    private var buttonColor: Color { role == .user ? Palette.purple : Palette.teal }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 40)

                    Image("AppLogoUI")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .accessibilityLabel("App logo")

                    Text("Join SUMAQ")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(accentColor)

                    VStack(alignment: .leading, spacing: 18) {
                        LabeledField(title: "Name", text: $name, placeholder: "Value", keyboard: .default, autocap: .words, labelColor: Palette.burgundy)
                        LabeledField(title: "Email", text: $email, placeholder: "Value", keyboard: .emailAddress, autocap: .never, labelColor: Palette.burgundy)
                            .textInputAutocapitalization(.never)
                        LabeledField(title: "Username", text: $username, placeholder: "Value", keyboard: .default, autocap: .never, labelColor: Palette.burgundy)
                            .textInputAutocapitalization(.never)
                        LabeledSecureField(title: "Password", text: $password, placeholder: "Value", labelColor: Palette.burgundy)
                            .textInputAutocapitalization(.never)

                        if role == .user {
                            Group {
                                LabeledField(title: "Budget (int)", text: $budget, placeholder: "25000", keyboard: .numberPad, labelColor: Palette.burgundy)
                                LabeledField(title: "Diet", text: $diet, placeholder: "vegetarian", keyboard: .default, labelColor: Palette.burgundy)

                                // ===== Imagen de perfil (usuario) =====
                                ImagePickerRow(
                                    title: "Profile picture",
                                    buttonColor: buttonColor,
                                    imageData: $userPhotoData,
                                    item: $userPhotoItem
                                )
                            }
                        } else {
                            Group {
                                LabeledField(title: "Address", text: $address, placeholder: "Calle 123 #45-67", keyboard: .default, labelColor: Palette.burgundy)
                                LabeledField(title: "Opening time (HHmm int)", text: $openingTime, placeholder: "900", keyboard: .numberPad, labelColor: Palette.burgundy)
                                LabeledField(title: "Closing time (HHmm int)", text: $closingTime, placeholder: "1900", keyboard: .numberPad, labelColor: Palette.burgundy)

                                // ===== Imagen principal (restaurante) =====
                                ImagePickerRow(
                                    title: "Restaurant image",
                                    buttonColor: buttonColor,
                                    imageData: $restPhotoData,
                                    item: $restPhotoItem
                                )

                                LabeledField(title: "Restaurant type", text: $restaurantType, placeholder: "Fast Food", keyboard: .default, labelColor: Palette.burgundy)

                                Toggle(isOn: $offer) {
                                    Text("Has Offer")
                                        .font(.custom("Montserrat-SemiBold", size: 16))
                                        .foregroundColor(Palette.burgundy)
                                }
                                .tint(buttonColor)

                                LabeledField(title: "Rating (0–5)", text: $ratingText, placeholder: "4.0", keyboard: .decimalPad, labelColor: Palette.burgundy)

                                LabeledField(title: "Busiest hours (comma list hour:level)", text: $busiestHoursText, placeholder: "1200:High,1500:Medium", keyboard: .default, labelColor: Palette.burgundy)
                            }
                        }
                    }

                    if let msg = controller.errorMsg {
                        Text(msg)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button { submit() } label: {
                        Text(controller.isLoading ? "Creating..." : "Register")
                            .font(.custom("Montserrat-SemiBold", size: 18))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(PrimaryCapsuleButton(color: buttonColor))
                    .padding(.top, 6)
                    .disabled(controller.isLoading || email.isEmpty || password.isEmpty || name.isEmpty)

                    NavigationLink(
                        destination: LoginView(role: role),
                        isActive: $controller.goToLogin
                    ) { EmptyView() }
                    .hidden()

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
        }
        // OBSERVER: la vista se SUSCRIBE a los eventos del controller
        .onReceive(NotificationCenter.default.publisher(for: .authDidRegister)) { _ in
            controller.goToLogin = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .authDidFail)) { notif in
            if let msg = notif.userInfo?["message"] as? String {
                controller.errorMsg = msg
            }
        }
        // Carga del ítem seleccionado (usuario)
        .onChange(of: userPhotoItem) { _, newItem in
            loadPhotoData(from: newItem) { data in userPhotoData = data }
        }
        // Carga del ítem seleccionado (restaurante)
        .onChange(of: restPhotoItem) { _, newItem in
            loadPhotoData(from: newItem) { data in restPhotoData = data }
        }
    }

    private func submit() {
        if role == .user {
            controller.registerUser(
                name: name, email: email, password: password,
                budget: Int(budget) ?? 0, diet: diet,
                profilePicture: "",
                profileImageData: userPhotoData       
            )
        } else {
            let openInt = Int(openingTime) ?? 0
            let closeInt = Int(closingTime) ?? 0
            let busiest = parseBusiestHours(busiestHoursText)
            let rating = Double(ratingText.replacingOccurrences(of: ",", with: ".")) ?? 0.0

            controller.registerRestaurant(
                name: name, email: email, password: password,
                address: address, opening: openInt, closing: closeInt,
                imageUrl: "",                         // ya no usamos URL
                typeOfFood: restaurantType, offer: offer, rating: rating, busiest: busiest,
                restaurantImageData: restPhotoData    // NUEVO
            )
        }
    }

    // "1200:High,1500:Medium" -> ["1200":"High","1500":"Medium"]
    private func parseBusiestHours(_ raw: String) -> [String:String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [:] }
        var dict: [String:String] = [:]
        trimmed.split(separator: ",").forEach { pair in
            let parts = pair.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { dict[parts[0]] = parts[1] }
        }
        return dict
    }

    private func loadPhotoData(from item: PhotosPickerItem?, done: @escaping (Data?) -> Void) {
        guard let item = item else { return done(nil) }
        Task {
            // intentamos JPEG/PNG de forma transparente
            if let data = try? await item.loadTransferable(type: Data.self) {
                done(data)
            } else {
                done(nil)
            }
        }
    }
}

// ====== Componente reutilizable para el picker de imágenes ======
private struct ImagePickerRow: View {
    let title: String
    let buttonColor: Color
    @Binding var imageData: Data?
    @Binding var item: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(Palette.burgundy)

            HStack(spacing: 12) {
                if let data = imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.2)))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Palette.grayLight)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.secondary)
                        )
                }

                PhotosPicker(selection: $item, matching: .images) {
                    Text(imageData == nil ? "Choose photo" : "Change photo")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(buttonColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
    }
}


// MARK: - Campos reutilizables
struct LabeledField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default
    var autocap: TextInputAutocapitalization = .never
    var labelColor: Color = Palette.burgundy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(labelColor)

            TextField(placeholder, text: $text)
                .font(.custom("Montserrat-Regular", size: 16))
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Palette.grayLight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct LabeledSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var labelColor: Color = Palette.burgundy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(labelColor)

            SecureField(placeholder, text: $text)
                .font(.custom("Montserrat-Regular", size: 16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Palette.grayLight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Botón principal
struct PrimaryCapsuleButton: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color)
            )
            .shadow(radius: configuration.isPressed ? 0 : 2,
                    x: 0, y: configuration.isPressed ? 0 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}


