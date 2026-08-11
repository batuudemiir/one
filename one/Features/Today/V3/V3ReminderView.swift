import SwiftUI

/// Hatırlatma & Bildirim ayar ekranı. Handoff step=4.
struct V3ReminderView: View {
    @State private var settings: V3ReminderSettings
    let onBack: () -> Void
    let onSave: (V3ReminderSettings) -> Void

    init(settings: V3ReminderSettings = V3ReminderSettings.load(),
         onBack: @escaping () -> Void,
         onSave: @escaping (V3ReminderSettings) -> Void) {
        _settings = State(initialValue: settings)
        self.onBack = onBack
        self.onSave = onSave
    }

    private let weekdayLabels = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V3Header(dateLabel: "AYARLAR · HATIRLATMA")
                .padding(.bottom, 12)

            V3BackButton(title: "← Geri", action: onBack)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Hatırlatma")
                        .font(V3Typography.display(34, weight: .black))
                        .tracking(-1.6)
                        .foregroundColor(V3Tokens.ink)
                        .padding(.top, 22)
                        .padding(.bottom, 6)

                    Text("Seçtiğin saatte tek hatırlatma.")
                        .font(V3Typography.sans(15))
                        .foregroundColor(V3Tokens.mutedText)
                        .lineSpacing(2)
                        .padding(.bottom, 22)

                    timeStepper

                    masterToggle
                        .padding(.top, 12)

                    weekdayChips
                        .padding(.top, 24)

                    tonePicker
                        .padding(.top, 24)

                    lockScreenPreview
                        .padding(.top, 24)
                }
            }

            Spacer(minLength: 18)

            V3PrimaryButton(
                title: "Kaydet",
                isFullWidth: true,
                horizontalPadding: 0,
                verticalPadding: 18,
                fontSize: 17
            ) {
                settings.save()
                onSave(settings)
            }
        }
    }

    // MARK: - Time stepper

    private var timeStepper: some View {
        HStack(spacing: 14) {
            stepperButton(symbol: "−") {
                let new = V3ReminderSettings.clamp(settings.minutes - V3ReminderSettings.step)
                settings.minutes = new
            }

            Spacer()

            Text(settings.formattedTime)
                .font(V3Typography.display(44, weight: .black))
                .tracking(-2.2)
                .monospacedDigit()
                .foregroundColor(V3Tokens.ink)

            Spacer()

            stepperButton(symbol: "+") {
                let new = V3ReminderSettings.clamp(settings.minutes + V3ReminderSettings.step)
                settings.minutes = new
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        )
    }

    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            action()
        }) {
            Text(symbol)
                .font(V3Typography.sans(20, weight: .regular))
                .foregroundColor(Color(hex: "#5A5A66"))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Master toggle

    private var masterToggle: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Günlük hatırlatma")
                    .font(V3Typography.sans(16, weight: .semibold))
                    .foregroundColor(V3Tokens.ink)
                Text(settings.enabled ? "Açık · her gün \(settings.formattedTime)" : "Kapalı · bildirim gelmez")
                    .font(V3Typography.sans(13))
                    .foregroundColor(V3Tokens.faintText)
            }

            Spacer()

            V3Switch(isOn: $settings.enabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        )
    }

    // MARK: - Weekday chips

    private var weekdayChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GÜNLER")
                .font(V3Typography.mono(11, weight: .regular))
                .tracking(1.4)
                .foregroundColor(V3Tokens.faintText)

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Button {
                        ONEHaptics.feelingSelected()
                        settings.days[i].toggle()
                    } label: {
                        Text(weekdayLabels[i])
                            .font(V3Typography.sans(13, weight: .semibold))
                            .foregroundColor(settings.days[i] ? V3Tokens.paper : V3Tokens.faintText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(settings.days[i] ? V3Tokens.ink : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(settings.days[i] ? V3Tokens.ink : V3Tokens.hairline, lineWidth: 1.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(V3Tokens.easingChip, value: settings.days[i])
                }
            }
        }
    }

    // MARK: - Tone picker

    private var tonePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NE DESİN?")
                .font(V3Typography.mono(11, weight: .regular))
                .tracking(1.4)
                .foregroundColor(V3Tokens.faintText)

            VStack(spacing: 8) {
                ForEach(V3ReminderTone.allCases) { tone in
                    Button {
                        ONEHaptics.feelingSelected()
                        settings.tone = tone
                    } label: {
                        HStack(spacing: 12) {
                            radio(isSelected: settings.tone == tone)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tone.displayName)
                                    .font(V3Typography.sans(15, weight: .semibold))
                                    .foregroundColor(V3Tokens.ink)
                                Text(tone.sampleBody)
                                    .font(V3Typography.sans(13))
                                    .foregroundColor(V3Tokens.faintText)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(V3Tokens.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(settings.tone == tone ? V3Tokens.ink : V3Tokens.hairline,
                                                lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func radio(isSelected: Bool) -> some View {
        Circle()
            .fill(isSelected ? V3Tokens.kor : Color.clear)
            .frame(width: 18, height: 18)
            .overlay(
                Circle()
                    .stroke(isSelected ? V3Tokens.kor : V3Tokens.dashed, lineWidth: 1.5)
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                    .padding(3)
            )
    }

    // MARK: - Lock-screen preview

    private var lockScreenPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KİLİT EKRANI ÖNİZLEMESİ")
                .font(V3Typography.mono(11, weight: .regular))
                .tracking(1.4)
                .foregroundColor(V3Tokens.faintText)

            VStack(spacing: 0) {
                Text(settings.formattedTime)
                    .font(V3Typography.display(38, weight: .semibold))
                    .tracking(-1.6)
                    .foregroundColor(V3Tokens.darkText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                Text(V3DateFormatter.headerLabel())
                    .font(V3Typography.mono(10, weight: .regular))
                    .tracking(1.4)
                    .foregroundColor(V3Tokens.darkMuted)
                    .padding(.top, 6)

                HStack(alignment: .top, spacing: 12) {
                    V3AppMark(side: 34, iconRadiusRatio: 9/34, wordmarkSize: 17, tracking: -1.1)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("ONE")
                                .font(V3Typography.mono(10, weight: .regular))
                                .tracking(1.2)
                                .foregroundColor(V3Tokens.darkMuted)
                            Spacer()
                            Text("şimdi")
                                .font(V3Typography.mono(10, weight: .regular))
                                .foregroundColor(Color(hex: "#6E6E7C"))
                        }
                        Text(previewNotification.title)
                            .font(V3Typography.sans(15, weight: .semibold))
                            .foregroundColor(V3Tokens.darkText)
                        Text(previewNotification.body)
                            .font(V3Typography.sans(14))
                            .foregroundColor(V3Tokens.darkMuted)
                            .lineSpacing(2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.09))
                )
                .padding(.top, 18)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(V3Tokens.ink)
            )
        }
    }

    private var previewNotification: (title: String, body: String) {
        // Preview'da "yesterdayMood" için gösterim amaçlı sabit örnek: sample body zaten
        // handoff'ta seçili tonun taglinei; canlı kayıt planlamasında gerçek data'yı
        // NotificationManager doldurur.
        switch settings.tone {
        case .quiet:   return ("Bugün.", "Tek kelime, tek renk.")
        case .short:   return ("Bugün nasılsın?", "On saniye sürer.")
        case .curious: return ("Dün maviydin.", "Bugün hangi renk?")
        }
    }
}

// MARK: - v3 switch

private struct V3Switch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            ONEHaptics.feelingSelected()
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? V3Tokens.kor : V3Tokens.hairline)
                    .frame(width: 52, height: 31)

                Circle()
                    .fill(Color.white)
                    .frame(width: 25, height: 25)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .animation(V3Tokens.easingChip, value: isOn)
    }
}
