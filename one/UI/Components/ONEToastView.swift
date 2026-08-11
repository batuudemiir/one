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

// MARK: - Toast Kartı (v3 spec)
// Üstte 18pt radius ink kart, kor nokta + mesaj + Kapat. `toastin` 0.28s
// giriş animasyonu — overlay wrapper zaten spring transition uyguluyor.
struct ONEToastView: View {
    let toast: ToastItem
    @ObservedObject private var handler = ErrorHandler.shared

    var body: some View {
        HStack(spacing: 12) {
            // v3: kor nokta (7pt) — tek vurgu.
            Circle()
                .fill(ONEBrand.kor)
                .frame(width: 7, height: 7)

            // Mesaj — tek satır (spec sadece message; title yoksa message'a düş).
            Text(toast.title.isEmpty ? toast.message : toast.title)
                .font(V3Typography.sans(14, weight: .medium))
                .foregroundColor(ONEBrand.bone)
                .lineLimit(2)

            Spacer(minLength: 4)

            if toast.isRetryable {
                Button(action: { handler.retry() }) {
                    Text(NSLocalizedString("general.retry", comment: ""))
                        .font(V3Typography.mono(11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(ONEBrand.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(ONEBrand.bone))
                }
                .accessibilityLabel(NSLocalizedString("general.retry", comment: ""))
            } else {
                Button(action: { handler.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ONEBrand.bone.opacity(0.6))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ONEBrand.ink)
        )
        .shadow(color: .black.opacity(0.16), radius: 20, x: 0, y: 6)
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
