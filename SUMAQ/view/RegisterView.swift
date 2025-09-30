import SwiftUI

struct RegisterView: View {
    let role: UserType

    // para usuario general en auth
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    // USER
    @State private var budget: String = ""
    @State private var diet: String = ""
    @State private var profilePicture: String = ""

    // RESTAURANT
    // RESTAURANT
    @State private var address: String = ""
    @State private var openingTime: String = ""
    @State private var closingTime: String = ""
    @State private var restaurantImage: String = ""   // se mapea a imageUrl
    @State private var restaurantType: String = ""    // se mapea a typeOfFood
    @State private var busiestHoursText: String = ""
    @State private var offer: Bool = false
    @State private var ratingText: String = ""


    // UI / navegación
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var goToLogin = false

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
                        .font(.system(size: 40, weight: .bold, design: .default))
                        .foregroundStyle(accentColor)
                        .kerning(1)

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
                                LabeledField(title: "Profile picture", text: $profilePicture, placeholder: "url o id", keyboard: .default, labelColor: Palette.burgundy)
                            }
                        } else {
                            Group {
                                LabeledField(title: "Address", text: $address, placeholder: "Calle 123 #45-67", keyboard: .default, labelColor: Palette.burgundy)
                                LabeledField(title: "Opening time (HHmm int)", text: $openingTime, placeholder: "900", keyboard: .numberPad, labelColor: Palette.burgundy)
                                LabeledField(title: "Closing time (HHmm int)", text: $closingTime, placeholder: "1900", keyboard: .numberPad, labelColor: Palette.burgundy)
                                LabeledField(title: "Restaurant image (URL)", text: $restaurantImage, placeholder: "url o id", keyboard: .default, labelColor: Palette.burgundy)
                                LabeledField(title: "Restaurant type", text: $restaurantType, placeholder: "Fast Food", keyboard: .default, labelColor: Palette.burgundy)
                                Toggle(isOn: $offer) {
                                    Text("Has Offer")
                                        .font(.custom("Montserrat-SemiBold", size: 16))
                                        .foregroundColor(Palette.burgundy)
                                }.tint(buttonColor)

                                LabeledField(title: "Rating (0–5)", text: $ratingText, placeholder: "4.0", keyboard: .decimalPad, labelColor: Palette.burgundy)

                                LabeledField(title: "Busiest hours (comma list hour:level)", text: $busiestHoursText, placeholder: "1200:High,1500:Medium", keyboard: .default, labelColor: Palette.burgundy)
                            }
                        }
                    }

                    if let errorMsg {
                        Text(errorMsg)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    //  register -> si todo bien, va a login
                    Button {
                        submit()
                    } label: {
                        Text(isLoading ? "Creating..." : "Register")
                            .font(.custom("Montserrat-SemiBold", size: 18))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(PrimaryCapsuleButton(color: buttonColor))
                    .padding(.top, 6)
                    .disabled(isLoading || email.isEmpty || password.isEmpty || name.isEmpty)

                    // va pa login si todo bien
                    NavigationLink(
                        destination: LoginView(role: role),
                        isActive: $goToLogin
                    ) { EmptyView() }
                    .hidden()

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func submit() {
        errorMsg = nil
        isLoading = true

        if role == .user {
            register(
                email: email,
                password: password,
                name: name,
                role: .user,
                // solo user
                budget: Int(budget) ?? 0,
                diet: diet,
                profilePicture: profilePicture
            ) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success: goToLogin = true
                    case .failure(let e): errorMsg = e.localizedDescription
                    }
                }
            }
        } else {
            let openInt = Int(openingTime) ?? 0
            let closeInt = Int(closingTime) ?? 0
            let busiest = parseBusiestHours(busiestHoursText)
            let rating = Double(ratingText.replacingOccurrences(of: ",", with: ".")) ?? 0.0

            register(
                email: email,
                password: password,
                name: name,
                role: .restaurant,
                // restaurant (mismos estados, solo mapeo a los nuevos params del register)
                address: address,
                openingTime: openInt,
                closingTime: closeInt,
                imageUrl: restaurantImage,
                typeOfFood: restaurantType,
                offer: offer,
                rating: rating,
                busiest_hours: busiest
                // user: nil por defecto
            ) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success: goToLogin = true
                    case .failure(let e): errorMsg = e.localizedDescription
                    }
                }
            }
        }
    }


    // "1200:High,1500:Medium" -> ["1200":"High","1500":"Medium"]
    private func parseBusiestHours(_ raw: String) -> [String:String] {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [:] }
        var dict: [String:String] = [:]
        raw.split(separator: ",").forEach { pair in
            let parts = pair.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { dict[parts[0]] = parts[1] }
        }
        return dict
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

//#Preview("Register – Usuario") {
//    RegisterView(role: .user)
//        .environment(\.colorScheme, .light)
//        .previewDevice("iPhone 15 Pro")
//}
//
//#Preview("Register – Restaurante") {
//    RegisterView(role: .restaurant)
//        .environment(\.colorScheme, .light)
//        .previewDevice("iPhone 15 Pro")
//}
