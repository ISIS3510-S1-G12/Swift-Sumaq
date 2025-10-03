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

    var body: some View {
        VStack(spacing: 18) {
            // Encabezado
            VStack(spacing: 6) {
                Text("People near \(restaurantName)")
                    .font(.custom("Montserrat-SemiBold", size: 20))
                    .foregroundColor(Palette.burgundy)
                Text("We anonymously scan nearby phones with SUMAQ open (Bluetooth).")
                    .font(.custom("Montserrat-Regular", size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Conteo grande
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

            // Estado
            if let err = crowd.lastError {
                Text(err).foregroundColor(.red).font(.footnote)
                    .padding(.horizontal, 16)
            } else if crowd.isScanning {
                ProgressView("Scanning…")
                    .padding(.top, 4)
            } else {
                Text("Tap scan to refresh the count.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }

            // Botones
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
        .onAppear { crowd.startQuickScan(duration: 12) } 
        .onDisappear { crowd.stop() }
    }
}
