//
//  PaywallView.swift
//  one
//
//  Premium sistemi devre dışı — bu view artık kullanılmıyor.
//

import SwiftUI

// MARK: - PaywallView (stub — premium devre dışı)

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("ONE+")
                .font(.system(size: 32, weight: .black))
            Text("Yakında geliyor.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            Button("Kapat") { dismiss() }
        }
        .padding()
    }
}

#Preview {
    PaywallView()
}
