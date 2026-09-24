//
//  ONEErrorView.swift
//  one
//
//  Merkezi hata gösterim bileşeni.
//  Maskot + mesaj + isteğe bağlı retry butonu.
//
//  Kullanım:
//    ONEErrorView(message: "Bir şeyler ters gitti.")
//    ONEErrorView(message: "Bağlantı kurulamadı.", onRetry: { viewModel.reload() })
//

import SwiftUI

struct ONEErrorView: View {
    let message: String
    var onRetry: (() -> Void)? = nil
    var size: CGFloat = 140

    var body: some View {
        VStack(spacing: V3Tokens.spacingXL) {
            OneMascotView(pose: .error, size: size, message: message)

            if let onRetry {
                Button(action: onRetry) {
                    Text(NSLocalizedString("general.retry", comment: ""))
                        .monoBase(tracking: 1.0)
                        .foregroundColor(V3Tokens.ink)
                        .padding(.horizontal, V3Tokens.spacingXL)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: V3Tokens.radiusCard)
                                .stroke(V3Tokens.ink.opacity(0.3), lineWidth: 1)
                        )
                }
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, V3Tokens.spacingXL)
    }
}

#Preview {
    ZStack {
        V3Tokens.paper.ignoresSafeArea()
        VStack(spacing: V3Tokens.spacingXL4) {
            ONEErrorView(message: "Bir şeyler ters gitti.")
            ONEErrorView(message: "Bağlantı kurulamadı.", onRetry: {})
        }
    }
}
