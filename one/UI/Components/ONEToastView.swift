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
                    .padding(.top, V3Tokens.spacingSM)
            }
            Spacer()
        }
        .animation(ONEAnimation.panelSpring, value: handler.currentToast?.id)
        .allowsHitTesting(handler.currentToast != nil)
    }
}

// MARK: - Toast Kartı (v3 spec)
// Üstte 18pt radius ink kart, kor nokta + mesaj + Kapat. `toastin` 0.28s
// giriş animasyonu — overlay wrapper zaten spring transition uyguluyor.
struct ONEToastView: View {
    let toast: ToastItem
    @ObservedObject private var handler = ErrorHandler.shared

    /// Yukarı kaydırarak kapatmanın canlı takibi.
    @State private var dragY: CGFloat = 0

    /// Kart yukarı çıktıkça soluyor: parmak henüz kalkmadan "bu hareket
    /// kapatıyor" bilgisini veriyor — sonucu haber veren ara kareler.
    private var dragOpacity: Double {
        1.0 - min(0.55, Double(max(0, -dragY)) / 90)
    }

    var body: some View {
        HStack(spacing: V3Tokens.spacingMD) {
            // v3: kor nokta (7pt) — tek vurgu.
            Circle()
                .fill(ONEBrand.kor)
                .frame(width: 7, height: 7)

            // Mesaj — tek satır (spec sadece message; title yoksa message'a düş).
            Text(toast.title.isEmpty ? toast.message : toast.title)
                .bodySMMedium()
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
                        .background(Capsule().fill(V3Tokens.surface))
                }
                .accessibilityLabel(NSLocalizedString("general.retry", comment: ""))
            } else {
                Button(action: { handler.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ONEBrand.bone.opacity(0.6))
                        .frame(width: 32, height: 32)
                }
                .contentShape(Rectangle())
                .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
            }
        }
        .padding(.horizontal, V3Tokens.spacingLG)
        .padding(.vertical, V3Tokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                .fill(ONEBrand.ink)
        )
        .shadow(color: .black.opacity(0.16), radius: 20, x: 0, y: 6)
        .padding(.horizontal, V3Tokens.spacingLG)
        .offset(y: dragY)
        .opacity(dragOpacity)
        // Kaydırarak kapatma.
        //
        // Önceden yalnız `.onEnded` vardı: parmak boyunca kart hiç
        // kıpırdamıyor, sonra ya birden kayboluyor ya hiçbir şey olmuyordu.
        // Jest sırasında geri bildirim olmayınca hareketin işe yarayıp
        // yaramadığı ancak bittikten sonra öğreniliyor.
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let dy = value.translation.height
                    // Yukarı 1:1, aşağı artan direnç — kartın gideceği
                    // bir aşağısı yok.
                    dragY = dy < 0
                        ? dy
                        : dy.rubberbanded(over: 120)
                }
                .onEnded { value in
                    let dy = value.translation.height
                    let projected = value.predictedEndTranslation.height
                    if dy < -36 || projected < -110 {
                        handler.dismiss()
                    } else {
                        withAnimation(ONEAnimation.dragSnapBack) {
                            dragY = 0
                        }
                    }
                }
        )
        // Yeni toast eski toast'ın kalıntı ofsetiyle belirmesin.
        .onChange(of: toast.id) { _, _ in dragY = 0 }
    }
}
