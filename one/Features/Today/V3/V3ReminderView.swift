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

    /// Gün kısaltmaları takvimden gelir — dokuz dile elle çeviri yazmak
    /// yerine `Calendar` locale'i veriyor. Pazartesi başlangıçlı.
    private var weekdayLabels: [String] {
        var cal = Calendar.current
        cal.locale = LanguageManager.shared.currentLocale
        let symbols = cal.shortWeekdaySymbols          // Pazar başlangıçlı
        return (0..<7).map { symbols[($0 + 1) % 7] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V3Header(dateLabel: "AYARLAR · HATIRLATMA")
                .padding(.bottom, V3Tokens.spacingMD)

            V3BackButton(title: NSLocalizedString("common.back", comment: ""), action: onBack)
                .padding(.top, V3Tokens.spacingSM)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(NSLocalizedString("reminder.title", comment: ""))
                        .font(V3Typography.display(34, weight: .black))
                        .tracking(-1.6)
                        .foregroundColor(V3Tokens.ink)
                        .padding(.top, V3Tokens.spacingXL)
                        .padding(.bottom, 6)

                    Text(NSLocalizedString("reminder.subtitle", comment: ""))
                        .bodyMD()
                        .foregroundColor(V3Tokens.mutedText)
                        .lineSpacing(2)
                        .padding(.bottom, V3Tokens.spacingXL)

                    timeStepper

                    masterToggle
                        .padding(.top, V3Tokens.spacingMD)

                    weekdayChips
                        .padding(.top, V3Tokens.spacingXL2)

                    tonePicker
                        .padding(.top, V3Tokens.spacingXL2)

                    lockScreenPreview
                        .padding(.top, V3Tokens.spacingXL2)
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
        .padding(V3Tokens.spacingXL)
        .oneCardBackground(radius: V3Tokens.radiusPanel)
    }

    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            action()
        }) {
            Text(symbol)
                .font(V3Typography.sans(20, weight: .regular))
                // Adaptive: ham #5A5A66 açık zemine göre seçilmişti, koyu
                // temada koyu zeminin üstünde okunmuyordu.
                .foregroundColor(V3Tokens.mutedText)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.onePressable)
    }

    // MARK: - Master toggle

    private var masterToggle: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("reminder.daily", comment: ""))
                    .bodyLGSemibold()
                    .foregroundColor(V3Tokens.ink)
                Text(settings.enabled
                     ? String(format: NSLocalizedString("reminder.state.on", comment: ""), settings.formattedTime)
                     : NSLocalizedString("reminder.state.off", comment: ""))
                    .bodyXS()
                    .foregroundColor(V3Tokens.faintText)
            }

            Spacer()

            V3Switch(isOn: $settings.enabled)
        }
        .padding(.horizontal, V3Tokens.spacingXL)
        .padding(.vertical, 18)
        .oneCardBackground(radius: V3Tokens.radiusPanel)
    }

    // MARK: - Weekday chips

    private var weekdayChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("reminder.days", comment: ""))
                .monoSM(weight: .regular)
                .tracking(1.4)
                .foregroundColor(V3Tokens.faintText)

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Button {
                        ONEHaptics.feelingSelected()
                        settings.days[i].toggle()
                    } label: {
                        Text(weekdayLabels[i])
                            .bodyXSSemibold()
                            .foregroundColor(settings.days[i] ? V3Tokens.paper : V3Tokens.faintText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, V3Tokens.spacingMD)
                            .background(
                                RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                                    .fill(settings.days[i] ? V3Tokens.ink : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                                            .stroke(settings.days[i] ? V3Tokens.ink : V3Tokens.hairline, lineWidth: 1.5)
                                    )
                            )
                    }
                    .buttonStyle(.onePressable)
                    .animation(ONEAnimation.easingChip, value: settings.days[i])
                }
            }
        }
    }

    // MARK: - Tone picker

    private var tonePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("reminder.tone", comment: ""))
                .monoSM(weight: .regular)
                .tracking(1.4)
                .foregroundColor(V3Tokens.faintText)

            VStack(spacing: V3Tokens.spacingSM) {
                ForEach(V3ReminderTone.allCases) { tone in
                    Button {
                        ONEHaptics.feelingSelected()
                        settings.tone = tone
                    } label: {
                        HStack(spacing: V3Tokens.spacingMD) {
                            radio(isSelected: settings.tone == tone)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tone.displayName)
                                    .bodyMDSemibold()
                                    .foregroundColor(V3Tokens.ink)
                                Text(tone.sampleBody)
                                    .bodyXS()
                                    .foregroundColor(V3Tokens.faintText)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, V3Tokens.spacingLG)
                        .background(
                            RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                                .fill(V3Tokens.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                                        .stroke(settings.tone == tone ? V3Tokens.ink : V3Tokens.hairline,
                                                lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.onePressable)
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
            Text(NSLocalizedString("reminder.lockPreview", comment: ""))
                .monoSM(weight: .regular)
                .tracking(1.4)
                .foregroundColor(V3Tokens.faintText)

            VStack(spacing: 0) {
                Text(settings.formattedTime)
                    .font(V3Typography.display(38, weight: .semibold))
                    .tracking(-1.6)
                    .foregroundColor(V3Tokens.darkText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, V3Tokens.spacingXS)

                Text(V3DateFormatter.headerLabel())
                    .monoLabel(weight: .regular)
                    .tracking(1.4)
                    .foregroundColor(V3Tokens.darkMuted)
                    .padding(.top, 6)

                HStack(alignment: .top, spacing: V3Tokens.spacingMD) {
                    V3AppMark(side: 34, iconRadiusRatio: 9/34, wordmarkSize: 17, tracking: -1.1)

                    VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
                        HStack {
                            Text("ONE")
                                .monoLabel(weight: .regular)
                                .tracking(1.2)
                                .foregroundColor(V3Tokens.darkMuted)
                            Spacer()
                            Text(NSLocalizedString("general.now", comment: ""))
                                .monoLabel(weight: .regular, tracking: 0)
                                // Aynı satırdaki kardeşi zaten `darkMuted`.
                                // Ham #6E6E7C, `ghostText`in erişilebilirlik
                                // düzeltmesi öncesi değeriydi — koyu bildirim
                                // zemininde 3.89:1, AA altı.
                                .foregroundColor(V3Tokens.darkMuted)
                        }
                        Text(previewNotification.title)
                            .bodyMDSemibold()
                            .foregroundColor(V3Tokens.darkText)
                        Text(previewNotification.body)
                            .bodySM()
                            .foregroundColor(V3Tokens.darkMuted)
                            .lineSpacing(2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                        .fill(Color.white.opacity(0.09))
                )
                .padding(.top, 18)
            }
            .padding(.horizontal, 18)
            .padding(.top, V3Tokens.spacingXL)
            .padding(.bottom, 18)
            .background(
                RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous)
                    .fill(V3Tokens.ink)
            )
        }
    }

    /// Kilit ekranı önizlemesi. Metin **gerçekten gönderilecek olanla aynı
    /// yerden** gelir (`V3ReminderTone` → `NotificationMessageBuilder`);
    /// burada ayrı bir örnek tablo tutuluyordu ve v3 sesinde kalmıştı.
    private var previewNotification: (title: String, body: String) {
        settings.tone.notification(yesterdayMood: nil)
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
        .buttonStyle(.onePressable)
        .animation(ONEAnimation.easingChip, value: isOn)
    }
}
