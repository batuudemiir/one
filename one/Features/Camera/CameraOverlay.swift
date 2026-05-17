//
//  CameraOverlay.swift
//  one
//
//  Pure SwiftUI camera controls overlay.
//  Minimalist editorial aesthetic — clean white on black/transparent.
//

import SwiftUI
import Combine

// MARK: - CameraOverlay

struct CameraOverlay: View {
    @ObservedObject var state:  CameraState
    private let ratio: CaptureRatio = .story
    let safeTop:    CGFloat
    let safeBottom: CGFloat
    let onDismiss:  () -> Void

    @State private var shutterDown  = false
    @State private var expBase: Float = 0
    @State private var expDragging  = false
    @State private var showEffects  = false

    private var bInset: CGFloat { max(safeBottom, 20) }
    private var sw: CGFloat { UIScreen.main.bounds.width  }
    private var sh: CGFloat { UIScreen.main.bounds.height }

    var body: some View {
        ZStack {
            // Frame mask — çerçeve dışı tam siyah
            GridFrameGuide(ratio: ratio, grid: state.grid)
                .allowsHitTesting(false)

            // Alt gradient — shutter zone görünürlüğü için
            if !state.isDismissing { bottomGradient }

            // AE/AF lock
            if state.isLocked { lockBanner }

            // Exposure handle
            if state.showExp, let pt = state.focusPt {
                exposureHandle(at: pt)
            }

            // Pinch zoom etiketi
            if state.pinching { zoomBadge }

            // Film efektleri
            if !state.isDismissing {
                if state.filmPreset.previewGrain > 0 {
                    FilmGrainView(intensity: state.filmPreset.previewGrain)
                }
                FilmVignetteView(intensity: state.filmPreset.previewVignette)
            }

            // Tüm kontroller
            controls
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.16), value: state.isLocked)
        .animation(.easeInOut(duration: 0.15), value: state.showExp)
        .animation(.easeInOut(duration: 0.12), value: state.pinching)
    }

    // MARK: - Bottom gradient

    private var bottomGradient: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [.clear, .black.opacity(0.45), .black.opacity(0.72)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: bInset + 220)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Controls

    private var controls: some View {
        ZStack {
            // Ana VStack — top bar + alt kontroller
            VStack(spacing: 0) {
                topBar
                Spacer()

            levelIndicator
                .padding(.bottom, 8)

            if state.pinching || abs(state.zoom - 1.0) > 0.05 {
                zoomPills
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            if showEffects {
                filmStrip
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

                shutterZone
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showEffects)
            .animation(.easeInOut(duration: 0.18), value: state.pinching)

            // Sağ rail — flaş + filtre + timer + grid, dikey, ekranın sağında ortalanmış
            VStack {
                Spacer().frame(height: safeTop + 100)
                HStack {
                    Spacer()
                    rightRail
                        .padding(.trailing, 16)
                }
                Spacer()
            }
        }
    }

    // MARK: - Top bar — sadece X (sol) + ONE (orta)

    private var topBar: some View {
        ZStack {
            HStack {
                plainBtn(sf: "xmark", sz: 16) { onDismiss() }
                    .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
                Spacer()
            }

            Text("ONE")
                .displaySM()
                .fontWeight(.black)
                .tracking(7)
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(.white.opacity(0.82))
                )
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, safeTop + 14)
    }

    // MARK: - Right rail — flaş + filtre + timer + grid (dikey sütun)

    private var rightRail: some View {
        VStack(spacing: 16) {
            // Flaş
            railBtn(
                sf: state.flash.icon,
                active: state.flash.isActive
            ) { if state.flashOK { state.cycleFlash() } }
            .opacity(state.flashOK ? 1 : 0.30)
            .accessibilityLabel(NSLocalizedString("accessibility.camera.flash", comment: ""))

            // Filtre
            railBtn(
                sf: "camera.filters",
                active: showEffects || state.filmPreset != .normal
            ) { showEffects.toggle() }
            .accessibilityLabel(NSLocalizedString("accessibility.camera.filmFilter", comment: ""))

            // Timer
            railBtn(
                sf: "timer",
                active: state.delay.isActive,
                badge: state.delay.badge
            ) { state.cycleDelay() }
            .accessibilityLabel(NSLocalizedString("accessibility.camera.timer", comment: ""))

            // Grid
            railBtn(
                sf: state.grid ? "square.grid.3x3.fill" : "square.grid.3x3",
                active: state.grid
            ) { state.toggleGrid() }
            .accessibilityLabel(NSLocalizedString("accessibility.camera.grid", comment: ""))
        }
    }

    private func railBtn(sf: String, active: Bool = false, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: sf)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(active ? .yellow : .white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.black.opacity(0.38))
                    )
                    .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)

                if let b = badge {
                    Text(b)
                        .monoMicro()
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 3).padding(.vertical, 1.5)
                        .background(Capsule().fill(.yellow))
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    // MARK: - Plain button (topBar için — kapat / flaş)

    private func plainBtn(sf: String, sz: CGFloat, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: sf)
                .font(.system(size: sz, weight: .semibold))
                .foregroundColor(active ? .yellow : .white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.black.opacity(0.38)))
                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
        }
    }

    // MARK: - Level indicator

    @ViewBuilder
    private var levelIndicator: some View {
        let p  = abs(state.pitch)
        let ok = p < 0.025
        if p > 0.01 && p < 0.35 {
            HStack(spacing: 5) {
                Rectangle().fill(ok ? Color.yellow : Color.white.opacity(0.8)).frame(width: 20, height: 1.5)
                Rectangle().fill(ok ? Color.yellow : Color.white.opacity(0.8)).frame(width: 20, height: 1.5)
            }
            .animation(.easeInOut(duration: 0.18), value: ok)
        }
    }

    // MARK: - Zoom pills

    private var zoomPills: some View {
        let presets = state.lensPresets
        return HStack(spacing: 5) {
            ForEach(Array(presets.enumerated()), id: \.offset) { idx, preset in
                let (factor, label) = preset
                let nextFactor: CGFloat = idx + 1 < presets.count ? presets[idx + 1].factor : CGFloat.infinity
                let active = state.zoom >= factor - 0.05 && state.zoom < nextFactor
                Button { state.zoomPreset(factor) } label: {
                    Text(label)
                        .bodySM()
                        .fontWeight(.semibold)
                        .foregroundColor(active ? .black : .white)
                        .padding(.horizontal, active ? 12 : 9)
                        .padding(.vertical, active ? 6 : 5)
                        .background(Capsule().fill(active ? Color.white.opacity(0.95) : Color.black.opacity(0.38)))
                        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: active)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(.black.opacity(0.22)))
    }

    // MARK: - Film strip

    private var filmStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(FilmPreset.allCases, id: \.self) { preset in
                    let active = state.filmPreset == preset
                    Button { state.selectFilmPreset(preset) } label: {
                        Text(preset.rawValue)
                            .monoSM()
                            .fontWeight(.semibold)
                            .foregroundColor(active ? .black : .white)
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(
                                Capsule().fill(active ? Color.white.opacity(0.95) : Color.black.opacity(0.32))
                            )
                            .overlay(
                                Capsule().stroke(active ? Color.white.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("\(NSLocalizedString("accessibility.camera.filmFilter", comment: "")): \(preset.rawValue)")
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 38)
    }

    // MARK: - Shutter zone

    private var shutterZone: some View {
        HStack {
            Color.clear.frame(width: 56, height: 56)
            Spacer()
            shutterBtn
            Spacer()
            // Flip
            Button { state.flip() } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .displayXS()
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.black.opacity(0.38)))
                    .shadow(color: .black.opacity(0.30), radius: 6, x: 0, y: 2)
            }
            .accessibilityLabel(NSLocalizedString("accessibility.camera.flip", comment: ""))
        }
        .padding(.horizontal, 28)
        .padding(.bottom, bInset + 24)
    }

    // MARK: - Shutter button

    private var shutterBtn: some View {
        Button {
            withAnimation(.spring(response: 0.14, dampingFraction: 0.5)) { shutterDown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.spring(response: 0.26)) { shutterDown = false }
            }
            state.shoot()
        } label: {
            ZStack {
                // Glow
                Circle()
                    .fill(
                        state.counting
                            ? Color.yellow.opacity(0.28)
                            : ONETokens.oneRed.opacity(state.capturing ? 0.40 : 0.15)
                    )
                    .frame(width: 104, height: 104)
                    .blur(radius: 16)

                // Dış halka
                Circle()
                    .stroke(
                        state.counting ? Color.yellow.opacity(0.90) : Color.white.opacity(0.90),
                        lineWidth: 3.5
                    )
                    .frame(width: 82, height: 82)

                // İç dolgu
                Circle()
                    .fill(state.counting ? Color.yellow : Color.white)
                    .frame(width: 66, height: 66)
                    .scaleEffect(shutterDown ? 0.72 : (state.capturing ? 0.85 : 1.0))
                    .animation(.spring(response: 0.18, dampingFraction: 0.6), value: state.capturing)

                if state.counting {
                    Image(systemName: "xmark")
                        .displayXS()
                        .fontWeight(.bold)
                        .foregroundColor(.black.opacity(0.70))
                }
            }
        }
        .disabled(state.capturing || state.isInRetakeCooldown)
        .opacity((state.capturing || state.isInRetakeCooldown) ? 0.5 : 1)
        .accessibilityLabel(state.counting
            ? NSLocalizedString("accessibility.camera.cancelTimer", comment: "")
            : NSLocalizedString("accessibility.camera.shutter", comment: ""))
    }

    // MARK: - AE/AF lock banner

    private var lockBanner: some View {
        VStack {
            Spacer()
            Text("AE/AF LOCK")
                .monoMicro()
                .fontWeight(.bold)
                .tracking(1.4)
                .foregroundColor(.black)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(.yellow))
                .padding(.bottom, bInset + 240)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Exposure handle

    @ViewBuilder
    private func exposureHandle(at pt: CGPoint) -> some View {
        let barH: CGFloat = 120
        let sunX  = min(pt.x + 58, sw - 36)
        let norm   = CGFloat((state.exposure - state.minExp) / (state.maxExp - state.minExp))
        let rawSunY: CGFloat = pt.y - barH * (norm - 0.5)
        let sunY   = rawSunY.clamped(to: (pt.y - barH / 2)...(pt.y + barH / 2))
        let fillH = max(CGFloat(0), min(barH, barH * norm))

        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 2, height: barH)
                .position(x: sunX, y: pt.y)
                .allowsHitTesting(false)
            Capsule()
                .fill(Color.yellow.opacity(0.85))
                .frame(width: 2, height: fillH)
                .position(x: sunX, y: pt.y + barH / 2 - fillH / 2)
                .allowsHitTesting(false)
            Image(systemName: abs(state.exposure) > 0.08 ? "sun.max.fill" : "sun.max")
                .displaySM()
                .fontWeight(.semibold)
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.55), radius: 3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .position(x: sunX, y: sunY)
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { v in
                            if !expDragging { expDragging = true; expBase = state.exposure }
                            let range = state.maxExp - state.minExp
                            let delta = Float(-v.translation.height / barH) * range
                            state.adjustExp((expBase + delta).clamped(to: state.minExp...state.maxExp))
                        }
                        .onEnded { _ in expDragging = false }
                )
            if abs(state.exposure) > 0.08 {
                Text(String(format: "%+.1f", state.exposure))
                    .monoMicro()
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .position(x: sunX + 26, y: sunY)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
    }

    // MARK: - Zoom badge

    private var zoomBadge: some View {
        Text(String(format: "%.1f×", state.zoom))
            .displayMD()
            .fontWeight(.bold)
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.4), radius: 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, bInset + 250)
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }
}

// MARK: - Film Grain

struct FilmGrainView: View {
    let intensity: Double
    @State private var seed: UInt64 = 1
    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            var rng  = LCG(state: seed)
            let count = Int(intensity * 900)
            for _ in 0..<count {
                let x = CGFloat(rng.nextFloat()) * size.width
                let y = CGFloat(rng.nextFloat()) * size.height
                let a = Double(rng.nextFloat()) * intensity * 0.65
                let r = CGFloat(rng.nextFloat()) * 1.4 + 0.4
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .onReceive(timer) { _ in seed = seed &* 6364136223846793005 &+ 1442695040888963407 }
    }
}

// MARK: - Film Vignette

struct FilmVignetteView: View {
    let intensity: Double

    var body: some View {
        RadialGradient(
            colors: [Color.clear, Color.black.opacity(intensity)],
            center: .center,
            startRadius: 120,
            endRadius: max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * 0.68
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - LCG random

struct LCG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func nextFloat() -> Float { Float(next() >> 33) / Float(1 << 31) }
}

// MARK: - GridFrameGuide

struct GridFrameGuide: View {
    let ratio: CaptureRatio
    let grid:  Bool
    private let cornerRadius: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            draw(w: geo.size.width, h: geo.size.height)
        }
    }

    @ViewBuilder
    private func draw(w: CGFloat, h: CGFloat) -> some View {
        // Fullscreen — black masks removed, entire screen is the capture area.
        // Corner brackets show the 9:16 crop boundary; cropImage handles the actual crop.
        let fr = CGRect(x: 0, y: 0, width: w, height: h)

        ZStack {
            // Grid (shows over full screen when enabled)
            if grid {
                let tgt = ratio.wh
                let cur = w / h
                let fw  = cur <= tgt ? w : h * tgt
                let fh  = cur <= tgt ? w / tgt : h
                let hPad = max((w - fw) / 2, 0)
                let vPad = max((h - fh) / 2, 0)
                let gfr  = CGRect(x: hPad, y: vPad, width: fw, height: fh)
                Path { p in
                    let x1 = gfr.minX + fw / 3, x2 = gfr.minX + fw * 2 / 3
                    let y1 = gfr.minY + fh / 3, y2 = gfr.minY + fh * 2 / 3
                    p.move(to: .init(x: x1, y: gfr.minY)); p.addLine(to: .init(x: x1, y: gfr.maxY))
                    p.move(to: .init(x: x2, y: gfr.minY)); p.addLine(to: .init(x: x2, y: gfr.maxY))
                    p.move(to: .init(x: gfr.minX, y: y1)); p.addLine(to: .init(x: gfr.maxX, y: y1))
                    p.move(to: .init(x: gfr.minX, y: y2)); p.addLine(to: .init(x: gfr.maxX, y: y2))
                }
                .stroke(Color.white.opacity(0.22), lineWidth: 0.75)
            }

            // Corner brackets — 4 L-shapes at screen corners
            let len: CGFloat = 28
            let bw:  CGFloat = 2.5
            let cr   = cornerRadius
            let cc   = Color.white.opacity(0.72)
            Path { p in
                // Top-left
                p.move(to: CGPoint(x: fr.minX + cr, y: fr.minY + bw / 2))
                p.addLine(to: CGPoint(x: fr.minX + cr + len, y: fr.minY + bw / 2))
                p.move(to: CGPoint(x: fr.minX + bw / 2, y: fr.minY + cr))
                p.addLine(to: CGPoint(x: fr.minX + bw / 2, y: fr.minY + cr + len))
                // Top-right
                p.move(to: CGPoint(x: fr.maxX - cr, y: fr.minY + bw / 2))
                p.addLine(to: CGPoint(x: fr.maxX - cr - len, y: fr.minY + bw / 2))
                p.move(to: CGPoint(x: fr.maxX - bw / 2, y: fr.minY + cr))
                p.addLine(to: CGPoint(x: fr.maxX - bw / 2, y: fr.minY + cr + len))
                // Bottom-left
                p.move(to: CGPoint(x: fr.minX + cr, y: fr.maxY - bw / 2))
                p.addLine(to: CGPoint(x: fr.minX + cr + len, y: fr.maxY - bw / 2))
                p.move(to: CGPoint(x: fr.minX + bw / 2, y: fr.maxY - cr))
                p.addLine(to: CGPoint(x: fr.minX + bw / 2, y: fr.maxY - cr - len))
                // Bottom-right
                p.move(to: CGPoint(x: fr.maxX - cr, y: fr.maxY - bw / 2))
                p.addLine(to: CGPoint(x: fr.maxX - cr - len, y: fr.maxY - bw / 2))
                p.move(to: CGPoint(x: fr.maxX - bw / 2, y: fr.maxY - cr))
                p.addLine(to: CGPoint(x: fr.maxX - bw / 2, y: fr.maxY - cr - len))
            }
            .stroke(cc, lineWidth: bw)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}

// MARK: - ScaleButtonStyle

struct ScaleButtonStyleCamera: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
