//
//  LastVisitNotification.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 14/10/25.
//

import SwiftUI

struct LastVisitNotification: View {
    @State private var lastVisitDate: Date?
    @State private var loading = true
    @State private var error: String?
    
    private let visitsRepo = VisitsRepository()
    
    var body: some View {
        Group {
            if loading {
                EmptyView() // No mostrar nada mientras carga
            } else if let lastVisitDate = lastVisitDate {
                let daysSince = Calendar.current.dateComponents([.day], from: lastVisitDate, to: Date()).day ?? 0
                print("🔍 DEBUG LastVisitNotification: Rendering with \(daysSince) days since last visit")
                
                // Solo mostrar la notificación si han pasado al menos 0 días (para testing, cambiar a 1 en producción)
                if daysSince >= 0 {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if daysSince == 0 {
                                Text("You visited a restaurant today!")
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                                    .foregroundColor(.white)
                            } else if daysSince == 1 {
                                Text("It's been a day since you tried a new restaurant!")
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                                    .foregroundColor(.white)
                            } else {
                                Text("It's been \(daysSince) days since you tried a new restaurant!")
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                                    .foregroundColor(.white)
                            }
                            Text("Last time was on \(formatDate(lastVisitDate))")
                                .font(.custom("Montserrat-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Palette.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 4)
                } else {
                    print("🔍 DEBUG LastVisitNotification: Not showing notification because daysSince (\(daysSince)) < 1")
                }
            } else {
                print("🔍 DEBUG LastVisitNotification: No last visit date found")
                // Mostrar mensaje de debug temporal cuando no hay visitas
                if ProcessInfo.processInfo.environment["DEBUG_VISITS"] == "true" {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debug: No visits found")
                                .font(.custom("Montserrat-SemiBold", size: 14))
                                .foregroundColor(.white)
                            Text("Try marking a restaurant as visited")
                                .font(.custom("Montserrat-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 4)
                }
            }
            // Si no hay visitas o hay error, no mostrar nada
        }
        .task { 
            print("🔍 DEBUG LastVisitNotification: Starting to load last visit")
            await loadLastVisit() 
        }
        .onReceive(NotificationCenter.default.publisher(for: .restaurantMarkedVisited)) { _ in
            print("🔍 DEBUG LastVisitNotification: Received restaurantMarkedVisited notification")
            Task { await loadLastVisit() }
        }
    }
    
    private func loadLastVisit() async {
        loading = true
        error = nil
        defer { loading = false }
        
        do {
            let visits = try await visitsRepo.getAllUserVisits()
            print("🔍 DEBUG LastVisitNotification: Found \(visits.count) visits")
            if let firstVisit = visits.first {
                print("🔍 DEBUG LastVisitNotification: Last visit was on \(firstVisit.visitedAt)")
                let daysSince = Calendar.current.dateComponents([.day], from: firstVisit.visitedAt, to: Date()).day ?? 0
                print("🔍 DEBUG LastVisitNotification: Days since last visit: \(daysSince)")
            }
            self.lastVisitDate = visits.first?.visitedAt
        } catch {
            print("❌ DEBUG LastVisitNotification: Error loading visits: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
