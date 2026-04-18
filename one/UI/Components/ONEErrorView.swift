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
        VStack(spacing: ONETokens.spacingXL) {
            OneMascotView(pose: .error, size: size, message: message)

            if let onRetry {
                Button(action: onRetry) {
                    Text(NSLocalizedString("general.retry", comment: ""))
                        .monoBase(tracking: 1.0)
                        .foregroundColor(ONETokens.oneInk)
                        .padding(.horizontal, ONETokens.spacingXL)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                                .stroke(ONETokens.oneInk.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, ONETokens.spacingXL)
    }
}

#Preview {
    ZStack {
        ONETokens.oneCream.ignoresSafeArea()
        VStack(spacing: 40) {
            ONEErrorView(message: "Bir şeyler ters gitti.")
            ONEErrorView(message: "Bağlantı kurulamadı.", onRetry: {})
        }
    }
}
