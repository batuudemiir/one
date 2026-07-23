//
//  TodayCompletedNudges.swift
//  one
//
//  Kaydedildi ekranının prototip dışı ekleri: push soft-ask, widget
//  önerisi ve pas günü görünümü. `TodayCompletedView.swift`'ten ayrıldı —
//  hepsi kendi kendine yeten, yalnız bir "kapatıldı" bayrağına bağlı.
//

import SwiftUI

// MARK: - Push Soft-Ask Banner

/// "Yarın da hatırlatayım mı?" — izin henüz sorulmamışken çıkan yumuşak
/// istek. Faz 4'te bilinçli olarak kaydın hemen ardına konuldu: kullanıcı
/// değeri gördükten sonra soruluyor, açılışta değil.
struct PushSoftAskBanner: View {
    /// Kalıcı kapatma bayrağı. Parent bunu okuyup banner'ı hiç çizmiyor.
    @Binding var dismissed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge")
                .bodyXL().fontWeight(.light)
                .foregroundColor(ONETokens.oneBrand)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Yarın da hatırlatayım mı?")
                    .bodySMMedium()
                    .foregroundColor(ONETokens.oneInk)
                Text("Günlük kayıtlar mood örüntünü oluşturur.")
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineSpacing(2)

                HStack(spacing: 8) {
                    Button {
                        dismiss()
                        NotificationManager.shared.requestAuthorization { granted in
                            if granted {
                                var comps = DateComponents()
                                comps.hour = 20
                                comps.minute = 0
                                if let date = Calendar.current.date(from: comps) {
                                    NotificationManager.shared.scheduleDailyReminder(at: date)
                                }
                            }
                        }
                    } label: {
                        Text("Evet, hatırlat")
                            .monoLabel(tracking: 0.4)
                            .foregroundColor(ONETokens.oneCream)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(ONETokens.oneInk))
                    }

                    Button { dismiss() } label: {
                        Text("Belki sonra")
                            .monoLabel(tracking: 0.4)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.oneCreamMid.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))
        )
    }

    private func dismiss() {
        UserDefaults.standard.set(true, forKey: "pushSoftAskDismissed")
        dismissed = true
    }
}

// MARK: - Widget Nudge Banner

/// Ana ekrana widget eklemeyi öneren küçük banner. Kalıcı olarak
/// kapatılabilir; bir kez kapatınca tekrar gösterilmez.
struct WidgetNudgeBanner: View {
    @Binding var dismissed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .bodyXL().fontWeight(.light)
                .foregroundColor(ONETokens.oneBrand)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("widget.nudge.title", comment: ""))
                    .bodySMMedium()
                    .foregroundColor(ONETokens.oneInk)
                Text(NSLocalizedString("widget.nudge.body", comment: ""))
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineSpacing(2)
            }

            Spacer(minLength: 8)

            Button {
                dismissed = true
                UserDefaults.standard.set(true, forKey: "widgetNudgeDismissed")
            } label: {
                Image(systemName: "xmark")
                    .monoSM().fontWeight(.semibold)
                    .foregroundColor(ONETokens.oneStone)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
            .accessibilityHint(NSLocalizedString("accessibility.widget.dismissHint", comment: "Widget önerisini kapat"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.oneCreamMid.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ONETokens.oneSilver, lineWidth: 1)
                )
        )
    }
}

// MARK: - #10 Pas Günü Görünümü

/// Bir gün "pas" geçildiğinde (kayıt yerine boş bırakıldığında) gösterilen
/// sade tamamlandı ekranı. Suçlayıcı değil — bir tire ve düzeltme yolu.
struct PassedDayView: View {
    let onEdit: () -> Void

    var body: some View {
        ZStack {
            ONETokens.oneCream.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("—")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundColor(ONETokens.oneMist)
                VStack(spacing: 8) {
                    Text(NSLocalizedString("today.passedDay.title", comment: ""))
                        .displayMD()
                        .foregroundColor(ONETokens.oneAsh)
                    Text(NSLocalizedString("today.passedDay.sub", comment: ""))
                        .monoSM(tracking: 0.4)
                        .foregroundColor(ONETokens.oneMist)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
                Button(action: onEdit) {
                    Text(NSLocalizedString("today.passedDay.cta", comment: ""))
                        .monoSM(tracking: 1.0)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.vertical, 12)
                }
                .padding(.bottom, 48)
            }
        }
    }
}
