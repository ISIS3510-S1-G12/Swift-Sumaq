//
//  LastVisitNotification.swift
//  SUMAQ
//
//  Created by AI Assistant on 2025-01-27.
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
                
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Have passed \(daysSince) days since you tried a new restaurant!")
                            .font(.custom("Montserrat-SemiBold", size: 14))
                            .foregroundColor(.white)
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
            }
            // Si no hay visitas o hay error, no mostrar nada
        }
        .task { await loadLastVisit() }
        .onReceive(NotificationCenter.default.publisher(for: .restaurantMarkedVisited)) { _ in
            Task { await loadLastVisit() }
        }
    }
    
    private func loadLastVisit() async {
        loading = true
        error = nil
        defer { loading = false }
        
        do {
            let visits = try await visitsRepo.getAllUserVisits()
            self.lastVisitDate = visits.first?.visitedAt
        } catch {
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
