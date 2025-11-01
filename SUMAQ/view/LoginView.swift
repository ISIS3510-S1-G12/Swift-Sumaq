//
//
//  LoginView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDOÑO on 20/09/25.
//

// LOCAL STORAGE # 3 - Keychain: Maria

//  using Keychain to store last login email.

import SwiftUI
import Security // LOCAL STORAGE:  for Keychain operations through KeychainHelper.
import SystemConfiguration // for network connectivity check.

struct LoginView: View {
    let role: UserType

    @State private var user: String = ""
    @State private var pass: String = ""
    @State private var isLoading = false
    @State private var showOfflineNotice = false
    @State private var goToUserHome = false
    @State private var goToRestaurantHome = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image("AppLogoUI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .cornerRadius(24)
                    .shadow(radius: 4, y: 2)
                    .padding(.top, 24)

                Text("WELCOME")
                    .font(.system(size: 40, weight: .bold, design: .default))
                    .foregroundColor(role == .restaurant ? Palette.teal : Palette.purple)
                    .tracking(1)

                VStack(alignment: .leading, spacing: 18) {
                    LabeledInput(label: "Email", text: $user, isSecure: false)
                    LabeledInput(label: "Password", text: $pass, isSecure: true)
                }
                .padding(.horizontal, 32)

                Button {
                    doLogin()
                } label: {
                    Text(isLoading ? "Signing in..." : "Log In")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(PrimaryCapsuleButton(color: role == .restaurant ? Palette.teal : Palette.purple))
                .padding(.horizontal, 32)
                .disabled(isLoading || user.isEmpty || pass.isEmpty)

                // EVENTUAL CONECTIVITY: Show offline notice below the login button.
                if showOfflineNotice {
                    ConnectivityNoticeCard(
                        title: "Offline mode",
                        message: "You are offline. You can sign in using the last saved credentials on this device. If they don’t match, please reconnect to verify your account."
                    )
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                NavigationLink(destination: UserRootView(),
                               isActive: $goToUserHome) { EmptyView() }
                    .hidden()

                NavigationLink(destination: RestaurantHomeView(),
                               isActive: $goToRestaurantHome) { EmptyView() }
                    .hidden()

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.ignoresSafeArea())
            // LOCAL STORAGE : Preload saved email on view appear using KeychainHelper
            .onAppear {
                if let savedEmail = KeychainHelper.shared.getLastLoginEmail() { // LOCAL STORAGE: Fetch email from Keychain
                    user = savedEmail // LOCAL STORAGE : Prefill email field if exists.
                }
            }
        }
    }

    private func doLogin() {
        showOfflineNotice = false
        isLoading = true

        // Check network connectivity
        if !NetworkHelper.shared.isConnectedToNetwork() {
            // No internet connection - try offline login
            // Check if user entered credentials match saved offline credentials
            if let savedCredentials = KeychainHelper.shared.getOfflineCredentials(),
               savedCredentials.email.lowercased() == user.lowercased() &&
               savedCredentials.password == pass {
                // Credentials match saved offline credentials - proceed with offline login
                loginOffline { result in
                    DispatchQueue.main.async {
                        isLoading = false
                        switch result {
                        case .success(let dest):
                            // Update email in Keychain
                            KeychainHelper.shared.saveLastLoginEmail(user)
                            
                            switch dest {
                            case .userHome:
                                goToUserHome = true
                            case .restaurantHome:
                                goToRestaurantHome = true
                            }
                        case .failure:
                            showOfflineNotice = true
                        }
                    }
                }
                return
            } else {
                // No internet and credentials don't match saved credentials
                DispatchQueue.main.async {
                    isLoading = false
                    //  EVENTUAL CONECTIVITY: Show friendly offline message instead of red error text.
                    showOfflineNotice = true
                }
                return
            }
        }

        // Has internet connection - proceed with normal login
        login(email: user, password: pass) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let dest):
                    // LOCAL STORAGE : Save email securely to Keychain on successful login.
                    KeychainHelper.shared.saveLastLoginEmail(user)

                    switch dest {
                    case .userHome:
                        goToUserHome = true
                    case .restaurantHome:
                        goToRestaurantHome = true
                    }
                case .failure:
                    showOfflineNotice = true
                }
            }
        }
    }
}

//  EVENTUAL CONECTIVITY: Friendly offline notice reused from other views (no red error).
private struct ConnectivityNoticeCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Montserrat-Bold", size: 16))
                .foregroundColor(.primary)
            Text(message)
                .font(.custom("Montserrat-Regular", size: 14))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.tertiaryLabel), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title). \(message)"))
    }
}

private struct LabeledInput: View {
    let label: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("Montserrat-Regular", size: 14))
                .foregroundColor(Palette.burgundy)

            Group {
                if isSecure {
                    SecureField("Value", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                } else {
                    TextField("Value", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(label.lowercased().contains("email") ? .emailAddress : .default)
                }
            }
            .font(.custom("Montserrat-Regular", size: 16))
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Palette.grayLight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
