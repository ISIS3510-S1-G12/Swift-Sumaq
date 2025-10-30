//
//  PeopleNearbyView.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//


import SwiftUI

struct PeopleNearbyView: View {
    let restaurantName: String

    @StateObject private var crowd = CrowdController()
    
    // Screen tracking
    @State private var screenStartTime: Date?

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("People near \(restaurantName)")
                    .font(.custom("Montserrat-SemiBold", size: 20))
                    .foregroundColor(Palette.burgundy)
                Text("We scan for nearby Bluetooth devices to detect people around you.")
                    .font(.custom("Montserrat-Regular", size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            ZStack {
                Circle()
                    .fill(Palette.purple.opacity(0.08))
                    .frame(width: 160, height: 160)
                VStack(spacing: 6) {
                    Text("\(crowd.nearbyCount)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Palette.purple)
                    Text("people nearby")
                        .font(.custom("Montserrat-SemiBold", size: 14))
                        .foregroundColor(Palette.purple)
                }
            }
            .padding(.top, 6)

            if let err = crowd.lastError {
                VStack(spacing: 8) {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    if err.contains("permission") || err.contains("Settings") {
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .font(.footnote)
                        .foregroundColor(.blue)
                    }
                    
                }
            } else if crowd.isScanning || crowd.isAdvertising {
                VStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(crowd.isScanning ? "Scanning for nearby devices..." : "Advertising presence...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                Text("Tap 'Scan' to detect nearby Bluetooth devices.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    
                }
            }

            HStack(spacing: 12) {
                Button {
                    crowd.startQuickScan(duration: 12)
                } label: {
                    Label("Scan", systemImage: "dot.radiowaves.left.and.right")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PrimaryCapsuleButton(color: Palette.purple))

                Button {
                    crowd.stop()
                } label: {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PrimaryCapsuleButton(color: Palette.grayLight))
                .disabled(!crowd.isScanning && !crowd.isAdvertising)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 24)
        .onAppear {
            screenStartTime = Date()
            SessionTracker.shared.trackScreenView(ScreenName.peopleNearby, category: ScreenCategory.socialFeatures)
            setupClosureCallbacks()
            crowd.startQuickScan(duration: 12)
        }
        .onDisappear {
            if let startTime = screenStartTime {
                let duration = Date().timeIntervalSince(startTime)
                SessionTracker.shared.trackScreenEnd(ScreenName.peopleNearby, duration: duration, category: ScreenCategory.socialFeatures)
            }
            cleanupClosureCallbacks()
            crowd.stop()
        }
    }
    
    private func setupClosureCallbacks() {
        // Wire closures with weak captures to avoid retain cycles
        crowd.onCentralStateChange = { [weak crowd] state in
            print("Central state changed to: \(state.rawValue)")
        }
        
        crowd.onPeripheralStateChange = { [weak crowd] state in
            print("Peripheral state changed to: \(state.rawValue)")
        }
        
        crowd.onScanStarted = { [weak crowd] in
            print("Scan started")
        }
        
        crowd.onScanStopped = { [weak crowd] count in
            print("Scan stopped. Total devices found: \(count)")
        }
        
        crowd.onDeviceFound = { [weak crowd] uuid, rssi, totalCount in
            print("Device found: \(uuid.uuidString), RSSI: \(rssi), Total: \(totalCount)")
        }
        
        crowd.onAdvertisingStarted = { [weak crowd] in
            print("Advertising started")
        }
        
        crowd.onAdvertisingStopped = { [weak crowd] error in
            if let error = error {
                print("Advertising stopped with error: \(error.localizedDescription)")
            } else {
                print("Advertising stopped")
            }
        }
        
        crowd.onError = { [weak crowd] errorMessage in
            print("Bluetooth error: \(errorMessage)")
        }
    }
    
    private func cleanupClosureCallbacks() {
        crowd.onCentralStateChange = nil
        crowd.onPeripheralStateChange = nil
        crowd.onScanStarted = nil
        crowd.onScanStopped = nil
        crowd.onDeviceFound = nil
        crowd.onAdvertisingStarted = nil
        crowd.onAdvertisingStopped = nil
        crowd.onError = nil
    }
}
