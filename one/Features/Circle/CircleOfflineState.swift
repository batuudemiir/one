//
//  CircleOfflineState.swift
//  one
//
//  Prototip 34 — çevrimdışı. Frekans'ın ayrı bir ekranı değil, bir hali.
//

import SwiftUI

/// Bağlantı yokken Frekans.
///
/// Prototipin buradaki duruşu ürünün tamamını özetliyor: hata ekranı
/// **çıkmaz sokak değil**. "Çevren yüklenemiyor" dedikten hemen sonra
/// "bugünkü rengini yine de bırakabilirsin — bağlantı gelince kendiliğinden
/// gider" diyor ve altında çevrimdışı çalışan her şeyi listeliyor.
///
/// Sebep basit: kayıt yerel, paylaşım uzak. Bağlantı yokluğu ritüeli
/// engellemiyor, sadece görünürlüğü erteliyor — ekran da bunu söylemeli.
struct CircleOfflineState: View {
    let onStartRitual: () -> Void
    let onRetry: () -> Void
    var onOpenArchive: (() -> Void)? = nil

    @State private var isRetrying = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Başlık Frekans'la aynı — kullanıcı başka bir yere
                // düşmedi, aynı ekranın bağlantısız hali.
                Text(NSLocalizedString("circle.title", comment: ""))
                    .displayLG()
                    .foregroundColor(V3Tokens.ink)

                Text(NSLocalizedString("offline.noConnection", comment: ""))
                    .monoLabel(tracking: 0.5)
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.top, 4)

                VStack(spacing: 11) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 38, weight: .light))
                        .foregroundColor(V3Tokens.faintText)

                    Text(NSLocalizedString("offline.title", comment: ""))
                        .displayMD()
                        .multilineTextAlignment(.center)
                        .foregroundColor(V3Tokens.ink)

                    Text(NSLocalizedString("offline.body", comment: ""))
                        .bodySM()
                        .multilineTextAlignment(.center)
                        .foregroundColor(V3Tokens.mutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onStartRitual) {
                        Text(NSLocalizedString("offline.leaveColour", comment: ""))
                            .bodySMMedium()
                            .foregroundColor(ONEBrand.bone)
                            .padding(.horizontal, 22)
                            .frame(minHeight: 44)
                            .background(Capsule(style: .continuous).fill(V3Tokens.ink))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)

                    Button {
                        isRetrying = true
                        onRetry()
                        // Görsel geri bildirim: dokunuş boşa gitmiş gibi
                        // durmasın. Gerçek sonuç dışarıdan geliyor.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            isRetrying = false
                        }
                    } label: {
                        if isRetrying {
                            ProgressView().tint(V3Tokens.mutedText)
                                .frame(minHeight: 44)
                        } else {
                            Text(NSLocalizedString("offline.retry", comment: ""))
                                .bodySMMedium()
                                .foregroundColor(V3Tokens.mutedText)
                                .frame(minHeight: 44)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRetrying)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 56)
                .padding(.horizontal, 24)

                Rectangle()
                    .fill(V3Tokens.ink.opacity(0.09))
                    .frame(height: 1)
                    .padding(.vertical, ONETokens.spacingXL)

                Text(NSLocalizedString("offline.readyOffline", comment: ""))
                    .monoLabel(tracking: 1.3)
                    .foregroundColor(V3Tokens.faintText)
                    .padding(.bottom, ONETokens.spacingSM)

                SettingsGroup {
                    SettingsRow(
                        icon: "square.grid.3x3",
                        title: NSLocalizedString("offline.yourArchive", comment: ""),
                        isLast: true,
                        action: onOpenArchive
                    )
                }
            }
            .padding(.horizontal, ONETokens.spacingXL)
            .padding(.top, ONETokens.spacingXL4)
            .padding(.bottom, 116)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
