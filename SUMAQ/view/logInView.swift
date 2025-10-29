//
//  LoginView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDOÑO on 20/09/25.
//

// PURPOSE: Login screen with email/password authentication
// ROOT CAUSE: NavigationLink with isActive binding was set on main thread but the binding update
//             timing could race with Firebase auth state propagation, preventing navigation.
// MULTITHREADING CHANGE: Use NavigationStack with path-based navigation for more reliable programmatic navigation.
//              Ensure all state updates are explicitly on MainActor with proper async/await handling.
// MARK: Strategy #3 (Swift Concurrency): Uses async/await with MainActor for thread-safe UI updates
// THREADING NOTE: All @State mutations and navigation triggers are guaranteed on MainActor via MainActor.run

import SwiftUI

struct LoginView: View {
    let role: UserType

    @State private var user: String = ""
    @State private var pass: String = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                    Task {
                        await doLogin()
                    }
                } label: {
                    Text(isLoading ? "Signing in..." : "Log In")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(PrimaryCapsuleButton(color: role == .restaurant ? Palette.teal : Palette.purple))
                .padding(.horizontal, 32)
                .disabled(isLoading || user.isEmpty || pass.isEmpty)

                if let errorMsg {
                    Text(errorMsg)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.ignoresSafeArea())
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .userHome:
                    UserRootView()
                case .restaurantHome:
                    RestaurantHomeView()
                }
            }
        }
    }

    @MainActor
    private func doLogin() async {
        errorMsg = nil
        isLoading = true

        do {
            let destination = try await loginAsync(email: user, password: pass)
            
            // Ensure state update is on main thread
            isLoading = false
            
            // Small delay to ensure Firebase auth state has propagated
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Navigate to destination on main thread
            navigationPath.append(destination)
        } catch {
            isLoading = false
            errorMsg = error.localizedDescription
        }
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

// Make AppDestination conform to Hashable for NavigationStack path
extension AppDestination: Hashable {}