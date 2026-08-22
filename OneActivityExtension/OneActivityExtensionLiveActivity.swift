//
//  OneActivityExtensionLiveActivity.swift
//  OneActivityExtension
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Hex renk

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: UInt64
        switch h.count {
        case 3:  (r, g, b) = ((int>>8)*17, (int>>4 & 0xF)*17, (int & 0xF)*17)
        case 6:  (r, g, b) = (int>>16, int>>8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (91, 141, 239)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }
}

// MARK: - Mood Badge (renkli daire + ikon)

struct MoodBadge: View {
    let hex: String
    let symbol: String
    let isDark: Bool
    let size: CGFloat
    var animStyle: String = "calm"   // "energetic" | "calm" | "deep"
    var animated: Bool = false

    private var fg: Color { isDark ? .white : .black }
    private var iconSize: CGFloat { size * 0.44 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: size, height: size)

            // `#available(iOS 17)` kapısı `symbolEffect` için vardı; efekt
            // kalktığı için gerek kalmadı — stil ayrımı düz SwiftUI.
            if animated {
                styledIcon
            } else {
                Image(systemName: symbol)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(fg)
            }
        }
    }

    /// Mood stiline göre farklılaşan ikon.
    ///
    /// Burada eskiden `.symbolEffect(… , options: .repeating)` vardı — üç stil
    /// için üç ayrı sürekli animasyon. Hiçbiri çalışmıyordu: Live Activity ve
    /// widget görünümleri arşivlenmiş anlık görüntü olarak çiziliyor, kod
    /// ekranda koşmuyor. `symbolEffect` sessizce yok sayılıyor — ne uyarı ne
    /// hata, yalnızca hiç gerçekleşmeyen bir animasyon.
    ///
    /// Live Activity'de hareket eden yalnızca iki şey var: timeline entry'leri
    /// arası geçiş ve `Text(_:style:)` sayaçları. Stil ayrımını bu yüzden
    /// statik olarak yapıyoruz — ağırlık, ikincil katman ve ölçek üçü de
    /// gerçekten çiziliyor, yani niyet korunuyor.
    private var styledIcon: some View {
        Group {
            switch animStyle {
            case "energetic":
                // Dolgun ve en büyük — enerjiyi kütleyle anlatıyor.
                Image(systemName: symbol)
                    .font(.system(size: iconSize * 1.06, weight: .bold))
                    .foregroundStyle(fg)
            case "deep":
                // Hiyerarşik render: tek renk içinde katmanlı, ağırbaşlı.
                Image(systemName: symbol)
                    .font(.system(size: iconSize, weight: .regular))
                    .foregroundStyle(fg)
                    .opacity(0.88)
            default: // "calm"
                Image(systemName: symbol)
                    .font(.system(size: iconSize * 0.96, weight: .medium))
                    .foregroundStyle(fg)
            }
        }
    }
}

// MARK: - Kutlama Expanded View (ilk 5 sn)

struct CelebrationExpandedView: View {
    let state: DailySongActivityAttributes.ContentState

    private var mood: Color { Color(hex: state.moodColorHex) }
    private var fg: Color { state.moodIsDark ? .white : .black }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()

                VStack(spacing: 6) {
                    MoodBadge(
                        hex: state.moodColorHex,
                        symbol: state.moodSFSymbol,
                        isDark: state.moodIsDark,
                        size: 48,
                        animStyle: state.moodAnimationStyle,
                        animated: true
                    )

                    Text(state.moodLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(mood)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("bugün kaydedildi")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Text(state.songName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(state.artistName)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .frame(maxWidth: 160, alignment: .leading)

                Spacer()
            }
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Normal Expanded View (5-30 sn)

struct NormalExpandedView: View {
    let state: DailySongActivityAttributes.ContentState
    private var mood: Color { Color(hex: state.moodColorHex) }

    var body: some View {
        HStack(spacing: 12) {
            MoodBadge(
                hex: state.moodColorHex,
                symbol: state.moodSFSymbol,
                isDark: state.moodIsDark,
                size: 40,
                animStyle: state.moodAnimationStyle,
                animated: true
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(state.moodLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(mood)
                }
                Text(state.songName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(state.artistName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(mood)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Lock Screen Banner

struct DailySongBannerView: View {
    let state: DailySongActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isCelebrating {
                CelebrationExpandedView(state: state)
                    .activityBackgroundTint(
                        Color(hex: state.moodColorHex).opacity(0.25)
                    )
            } else {
                NormalExpandedView(state: state)
                    .activityBackgroundTint(Color(white: 0.08))
            }
        }
    }
}

// MARK: - Daily Song Widget

struct DailySongLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailySongActivityAttributes.self) { context in
            DailySongBannerView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // EXPANDED
                DynamicIslandExpandedRegion(.leading) {
                    MoodBadge(
                        hex: context.state.moodColorHex,
                        symbol: context.state.moodSFSymbol,
                        isDark: context.state.moodIsDark,
                        size: context.state.isCelebrating ? 50 : 40,
                        animStyle: context.state.moodAnimationStyle,
                        animated: true
                    )
                    .padding(.leading, 2)
                    .animation(.easeInOut(duration: 0.4), value: context.state.isCelebrating)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isCelebrating {
                        // Kutlama sırasında: checkmark (iOS 17+ bounce, iOS 16 statik)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(hex: context.state.moodColorHex))
                            .modifier(BouncingSealModifier())
                            .padding(.trailing, 4)
                    } else {
                        VStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: context.state.moodColorHex))
                        }
                        .padding(.trailing, 4)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    if context.state.isCelebrating {
                        VStack(spacing: 3) {
                            Text("kaydedildi")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                            Text(context.state.songName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    } else {
                        VStack(spacing: 3) {
                            Text(context.state.songName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(context.state.artistName)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(hex: context.state.moodColorHex))
                            .frame(width: 6, height: 6)
                        Text(context.state.moodLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: context.state.moodColorHex))
                        Spacer()
                        if !context.state.isCelebrating {
                            Text(context.state.artistName)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.35))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                }

            } compactLeading: {
                MoodBadge(
                    hex: context.state.moodColorHex,
                    symbol: context.state.moodSFSymbol,
                    isDark: context.state.moodIsDark,
                    size: 24,
                    animStyle: context.state.moodAnimationStyle,
                    animated: true
                )

            } compactTrailing: {
                Text(context.state.songName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 90, alignment: .trailing)

            } minimal: {
                MoodBadge(
                    hex: context.state.moodColorHex,
                    symbol: context.state.moodSFSymbol,
                    isDark: context.state.moodIsDark,
                    size: 20,
                    animStyle: context.state.moodAnimationStyle,
                    animated: true
                )
            }
            .keylineTint(Color(hex: context.state.moodColorHex))
        }
    }
}

// MARK: - Friend Share Widget

struct FriendShareLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FriendShareActivityAttributes.self) { context in
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 44, height: 44)
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.8))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(context.state.friendName) paylaştı")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(context.state.songName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(context.state.artistName)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer()
                MoodBadge(
                    hex: context.state.moodColorHex,
                    symbol: context.state.moodSFSymbol,
                    isDark: true,
                    size: 34,
                    animated: false
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color(white: 0.08))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.1)).frame(width: 36, height: 36)
                        Image(systemName: "person.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MoodBadge(
                        hex: context.state.moodColorHex,
                        symbol: context.state.moodSFSymbol,
                        isDark: true,
                        size: 32,
                        animated: false
                    )
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        Text(context.state.friendName)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(context.state.songName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(context.state.artistName)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.moodLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: context.state.moodColorHex))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } compactLeading: {
                Image(systemName: "person.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            } compactTrailing: {
                Text("\(context.state.friendName) paylaştı")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } minimal: {
                MoodBadge(
                    hex: context.state.moodColorHex,
                    symbol: context.state.moodSFSymbol,
                    isDark: true,
                    size: 20,
                    animated: false
                )
            }
            .keylineTint(Color(hex: context.state.moodColorHex))
        }
    }
}

// MARK: - Kutlama mührü

/// Kutlama fazındaki `checkmark.seal.fill` vurgusu.
///
/// Burada `.symbolEffect(.bounce, value:)` vardı, `onAppear` içinde artan bir
/// tetikleyiciyle. Live Activity'de ikisi de çalışmıyor: görünüm arşivlenmiş
/// anlık görüntü, `onAppear` kullanıcı ekranı görürken koşmuyor ve
/// `symbolEffect` sessizce yok sayılıyor.
///
/// Mühür zaten yalnız kutlama fazında (ilk 5 sn) çiziliyor; asıl "hareket"
/// duygusu o fazdan normal faza geçerken timeline entry değişiminden geliyor —
/// sistem bu geçişi kendisi yumuşatıyor. Modifier'ın işi artık statik vurgu.
struct BouncingSealModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .bold))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
    }
}
