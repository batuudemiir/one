//
//  DoneScreen.swift
//  one
//
//  Post-save confirmation screen
//

import SwiftUI

struct DoneScreen: View {
    @ObservedObject var vm: ColorPickerViewModel
    let moodCoreNS: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Wave animation
    @State private var waveScale: CGFloat = 0
    @State private var waveOpacity: Double = 1
    @State private var backgroundTinted = false

    // Vivid burst — Apple Watch full-bleed moment
    @State private var vividBurstScale: CGFloat = 0
    @State private var vividBurstOpacity: Double = 0

    // Contour flow background — Watch yavaş akan kontur dalgaları
    @State private var contourVisible = false

    // Staggered content reveal
    @State private var showCheck = false
    @State private var showTitle = false
    @State private var showMeta = false
    @State private var showMedia = false

    // Live waveform — soldan sağa çizilen Watch kalp ritmi çizgisi
    @State private var waveformProgress: CGFloat = 0

    // Variable micro-reward — her girişte rastgele 5 animasyondan biri
    @State private var rewardVariant = Int.random(in: 0..<5)

    private var moodColor: Color { vm.selectedMood?.color ?? ONETokens.oneInk }
    private var moodPastelColor: Color { vm.selectedMood?.pastelColor ?? ONETokens.oneCreamMid }

    var body: some View {
        ZStack {
            // Faz 2: Settling background tint (mood renginin %12 opaklığı)
            ONETokens.oneCream
                .overlay(moodPastelColor.opacity(backgroundTinted ? 0.18 : 0))
                .animation(.easeInOut(duration: ONEAnimation.durationLong), value: backgroundTinted)
                .ignoresSafeArea()

            // Contour flow — burst geçtikten sonra yavaşça açılan dalga çizgileri
            ContourBackground(color: moodColor)
                .opacity(contourVisible ? 1 : 0)
                .animation(.easeIn(duration: 1.0).delay(0.5), value: contourVisible)
                .ignoresSafeArea()

            // Faz 0: matchedGeometryEffect landing — mood dairesi ConfirmScreen'den uçup gelir
            // waveOpacity ile birlikte solar (dalga genişlerken kaybolur)
            GeometryReader { geo in
                Circle()
                    .fill(moodPastelColor)
                    .frame(width: 56, height: 56)
                    .matchedGeometryEffect(id: "moodCore", in: moodCoreNS)
                    .opacity(waveOpacity)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            // Vivid burst — Apple Watch "workout complete" anı: doygun renk, hızlı gelir hızlı gider
            GeometryReader { geo in
                Circle()
                    .fill(moodColor)
                    .frame(
                        width: max(geo.size.width, geo.size.height) * 2.8,
                        height: max(geo.size.width, geo.size.height) * 2.8
                    )
                    .scaleEffect(vividBurstScale)
                    .opacity(vividBurstOpacity)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            // Faz 1: Renk dalgası — merkezden yayılan daire
            GeometryReader { geo in
                Circle()
                    .fill(moodPastelColor)
                    .frame(
                        width: max(geo.size.width, geo.size.height) * 2.8,
                        height: max(geo.size.width, geo.size.height) * 2.8
                    )
                    .scaleEffect(waveScale)
                    .opacity(waveOpacity)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            // Faz 3: İçerik — staggered giriş
            VStack(spacing: 0) {
                Spacer()

                Circle()
                    .fill(ONETokens.oneInk)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 26, weight: .medium))
                    )
                    .scaleEffect(reduceMotion ? 1 : (showCheck ? 1 : 0.4))
                    .opacity(showCheck ? 1 : 0)
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.15) : ONEAnimation.cardSpring.delay(0.45),
                        value: showCheck
                    )
                    .padding(.bottom, 36)

                Text(NSLocalizedString("done.saved", comment: ""))
                    .displayXL()
                    .foregroundColor(ONETokens.oneInk)
                    .padding(.bottom, 12)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (showTitle ? 0 : 10))
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.15) : ONEAnimation.panelSpring.delay(0.55),
                        value: showTitle
                    )

                Text("\(vm.selectedSong?.name ?? "") · \(vm.selectedMood?.label ?? "")")
                    .monoSM(tracking: 1.5)
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.bottom, 8)
                    .opacity(showMeta ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (showMeta ? 0 : 8))
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.15) : ONEAnimation.panelSpring.delay(0.65),
                        value: showMeta
                    )

                // Live waveform
                if let mood = vm.selectedMood {
                    LiveWaveformView(mood: mood, progress: waveformProgress)
                        .opacity(showMeta ? 1 : 0)
                        .padding(.horizontal, 48)
                        .padding(.top, 4)
                        .animation(.easeIn(duration: 0.3).delay(0.65), value: showMeta)
                }

                if vm.calendarSyncEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 11))
                        Text(NSLocalizedString("done.calendarAdded", comment: ""))
                            .monoBase()
                    }
                    .foregroundColor(ONETokens.oneGreen)
                    .padding(.bottom, 52)
                    .opacity(showMeta ? 1 : 0)
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.15) : ONEAnimation.panelSpring.delay(0.72),
                        value: showMeta
                    )
                } else {
                    Spacer().frame(height: 60)
                }

                VStack(spacing: 16) {
                    if let photo = vm.selectedPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 12)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(moodColor)
                            .frame(width: 90, height: 90)
                            .shadow(color: moodColor.opacity(0.3), radius: 20, x: 0, y: 12)
                    }

                    Text(NSLocalizedString(vm.selectedPhoto != nil ? "done.todaysMemory" : "done.todaysColor", comment: ""))
                        .monoBase(tracking: 2)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.top, 4)

                    Text(vm.selectedMood?.label ?? "")
                        .displayMD()
                        .foregroundColor(ONETokens.oneInk)
                }
                .padding(28)
                .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .opacity(showMedia ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (showMedia ? 1 : 0.92))
                .animation(
                    reduceMotion ? .easeOut(duration: 0.15) : ONEAnimation.cardSpring.delay(0.75),
                    value: showMedia
                )

                Spacer()
            }

            // Variable micro-reward overlay — içeriğin ÜSTÜNDE, tüm animasyonlar
            // opacity 0'a inerek solar; içerik alttan yükselir.
            if !reduceMotion {
                RewardOverlayView(variant: rewardVariant, color: moodColor)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            if reduceMotion {
                // Reduce Motion: tüm animasyonlar atlanır, içerik anında görünür
                waveOpacity = 0
                backgroundTinted = true
                contourVisible = false
                waveformProgress = 0
                showCheck = true
                showTitle = true
                showMeta = true
                showMedia = true
            } else {
                // Vivid burst: doygun renk hızla patlar, hemen solar
                withAnimation(.easeOut(duration: 0.22)) {
                    vividBurstScale = 1
                    vividBurstOpacity = 0.78
                }
                withAnimation(.easeIn(duration: 0.28).delay(0.18)) {
                    vividBurstOpacity = 0
                }

                // Faz 1: Pastel dalga yayılır ve solar
                withAnimation(.easeOut(duration: 0.7)) {
                    waveScale = 1
                }
                withAnimation(.easeIn(duration: 0.5).delay(0.35)) {
                    waveOpacity = 0
                }

                // Faz 2: Arka plan rengi oturur
                withAnimation(.easeInOut(duration: ONEAnimation.durationLong).delay(0.2)) {
                    backgroundTinted = true
                }

                // Contour dalgaları burst bittikten sonra açılır
                contourVisible = true

                // Waveform: dalga geçtikten sonra çizilmeye başlar
                withAnimation(.easeInOut(duration: 1.5).delay(0.65)) {
                    waveformProgress = 1.0
                }

                // Faz 3: İçerik staggered giriş
                showCheck = true
                showTitle = true
                showMeta = true
                showMedia = true
            }
        }
    }
}

// MARK: - Live Waveform

private struct LiveWaveformView: View {
    let mood: ONEMood
    let progress: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            Canvas { ctx, size in
                guard progress > 0.01 else { return }
                let t     = tl.date.timeIntervalSinceReferenceDate
                let drawW = size.width * progress
                let amp   = min(CGFloat(mood.waveHeight) * 0.52, size.height * 0.36)
                let yMid  = size.height / 2
                var path  = Path()
                var first = true

                stride(from: 0.0, through: drawW, by: 1.5).forEach { x in
                    let y  = yMid + amp * sin(x / 26.0 + t * 1.7)
                    let pt = CGPoint(x: x, y: y)
                    if first { path.move(to: pt); first = false } else { path.addLine(to: pt) }
                }

                ctx.stroke(
                    path,
                    with: .color(mood.color.opacity(0.48)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )

                if drawW > 5 {
                    let capY = yMid + amp * sin(drawW / 26.0 + t * 1.7)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: drawW - 3, y: capY - 3, width: 6, height: 6)),
                        with: .color(mood.color.opacity(0.9))
                    )
                }
            }
        }
        .frame(height: 30)
        .allowsHitTesting(false)
    }
}

// MARK: - Variable Reward Overlay

private struct RewardOverlayView: View {
    let variant: Int
    let color: Color
    var body: some View {
        ZStack {
            switch variant {
            case 0: RingPulseReward(color: color)
            case 1: ConfettiDotsReward(color: color)
            case 2: SparkleReward(color: color)
            case 3: ColorFlashReward(color: color)
            default: BubblePopReward(color: color)
            }
        }
    }
}

private struct RingPulseReward: View {
    let color: Color
    @State private var active = false
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .strokeBorder(color.opacity(0.55 - Double(i) * 0.12), lineWidth: 1.5)
                    .frame(width: 90, height: 90)
                    .scaleEffect(active ? 7 : 0.3)
                    .opacity(active ? 0 : 1)
                    .animation(.easeOut(duration: 0.75).delay(Double(i) * 0.13), value: active)
            }
        }
        .onAppear { active = true }
    }
}

private struct ConfettiDotsReward: View {
    let color: Color
    @State private var spread = false
    private let angles: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
    var body: some View {
        ZStack {
            ForEach(Array(angles.enumerated()), id: \.offset) { i, deg in
                let rad = deg * .pi / 180
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .offset(
                        x: spread ? CGFloat(cos(rad)) * 130 : 0,
                        y: spread ? CGFloat(sin(rad)) * 130 : 0
                    )
                    .opacity(spread ? 0 : 0.85)
                    .animation(.easeOut(duration: 0.65).delay(Double(i) * 0.02), value: spread)
            }
        }
        .onAppear { spread = true }
    }
}

private struct SparkleReward: View {
    let color: Color
    @State private var scale: CGFloat = 0.01
    @State private var opacity: Double = 1
    private let positions: [(CGFloat, CGFloat)] = [
        (-65, -90), (65, -90), (-100, 0), (100, 0), (-65, 90), (65, 90)
    ]
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(color.opacity(0.85))
                    .offset(x: positions[i].0, y: positions[i].1)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { scale = 1.0 }
            withAnimation(.easeIn(duration: 0.3).delay(0.42)) { opacity = 0 }
        }
    }
}

private struct ColorFlashReward: View {
    let color: Color
    @State private var opacity: Double = 0.30
    var body: some View {
        Rectangle()
            .fill(color)
            .opacity(opacity)
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeIn(duration: 0.55).delay(0.08)) { opacity = 0 }
            }
    }
}

private struct BubblePopReward: View {
    let color: Color
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0.50
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 180, height: 180)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.48)) { scale = 1.9 }
                withAnimation(.easeIn(duration: 0.32).delay(0.32)) { opacity = 0 }
            }
    }
}

// MARK: - Contour Background

private struct ContourBackground: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for i in 0..<5 {
                    let fi = Double(i)
                    var path = Path()
                    let yBase  = size.height * (0.15 + fi * 0.18)
                    let amp    = size.height * (0.022 + fi * 0.004)
                    let freq   = 1.3  + fi * 0.25
                    let speed  = 0.10 + fi * 0.02
                    let phase  = fi   * 1.3
                    var first  = true

                    stride(from: 0.0, through: size.width, by: 3.0).forEach { x in
                        let y  = yBase + amp * sin(x / size.width * .pi * 2 * freq + t * speed + phase)
                        let pt = CGPoint(x: x, y: y)
                        if first { path.move(to: pt); first = false } else { path.addLine(to: pt) }
                    }

                    let opacity = max(0.02, 0.055 - fi * 0.007)
                    ctx.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 0.8)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
