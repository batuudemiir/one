//
//  ONEToastView.swift
//  one
//
//  Wabi-Sabi tarzında minimal toast/banner bileşeni.
//  ErrorHandler.shared.currentToast ile otomatik gösterilir.
//
//  Kullanım: Ana ZStack'e `.overlay { ONEToastOverlay() }` ekleyin.
//

import SwiftUI

// MARK: - Toast Overlay (Üst katman)
struct ONEToastOverlay: View {
    @ObservedObject private var handler = ErrorHandler.shared
    
    var body: some View {
        VStack {
            if let toast = handler.currentToast {
                ONEToastView(toast: toast)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
                    .padding(.top, 8)
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: handler.currentToast?.id)
        .allowsHitTesting(handler.currentToast != nil)
    }
}

// MARK: - Toast Kartı
struct ONEToastView: View {
    let toast: ToastItem
    @ObservedObject private var handler = ErrorHandler.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // İkon
            Image(systemName: toast.type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(toast.type.color)
            
            // Mesaj
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .bodySMMedium()
                    .foregroundColor(ONETokens.oneInk)

                Text(toast.message)
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            // Retry veya Dismiss
            if toast.isRetryable {
                Button(action: { handler.retry() }) {
                    Text(NSLocalizedString("general.retry", comment: ""))
                        .monoLabel(tracking: 0.5)
                        .foregroundColor(ONETokens.oneCream)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(toast.type.color)
                        )
                }
                .accessibilityLabel(NSLocalizedString("general.retry", comment: ""))
            } else {
                Button(action: { handler.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ONETokens.oneStone)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(ONETokens.oneSilver).frame(width: 24, height: 24))
                }
                .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(toast.type.color.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if value.translation.height < -20 {
                        handler.dismiss()
                    }
                }
        )
    }
}
