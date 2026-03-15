//
//  TodayView.swift
//  One - Günlük Mood
//

import SwiftUI
import CoreData

struct TodayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var vm: TodayViewModel
    @Binding var entryStep: Step

    // Save Ritual animasyonu
    @State private var showRitual:       Bool    = false
    @State private var ritualColor:      Color   = .clear
    // Katman 1 — solid fill burst
    @State private var burstScale:       CGFloat = 0
    @State private var burstOpacity:     Double  = 1
    // Katman 2 — sonar ring (birinci)
    @State private var ringScale:        CGFloat = 0
    @State private var ringOpacity:      Double  = 0
    @State private var ringLineWidth:    CGFloat = 1.5
    // Katman 3 — ikinci halka (derin: su dalgası / ateşli: mini patlama)
    @State private var ring2Scale:       CGFloat = 0
    @State private var ring2Opacity:     Double  = 0
    // Katman 4 — glow bloom (bulanık merkez parlaması)
    @State private var glowOpacity:      Double  = 0
    // Katman 5 — ışın demetleri (yalnız ışıklı)
    @State private var rayScale:         CGFloat = 0
    @State private var rayOpacity:       Double  = 0
    @State private var rayRotation:      Double  = 0
    // Katman 6 — vignette (yalnız gizemli)
    @State private var vignetteOpacity:  Double  = 0
    // Katman 7 — background tint
    @State private var bgTinted:         Bool    = false
    @State private var bgTintLevel:      Double  = 0.11
    // Katman 8 — particle efektleri
    @State private var ritualMood:       ONEMood? = nil

    init(context: NSManagedObjectContext, entryStep: Binding<Step>) {
        _vm = StateObject(wrappedValue: TodayViewModel(context: context))
        _entryStep = entryStep
    }

    var body: some View {
        ZStack {
            // Ekranlar arası geçiş
            Group {
                switch vm.todayState {
                case .empty:
                    TodayEmptyView(vm: vm, currentStep: $entryStep)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .scale(scale: 0.96).combined(with: .opacity)
                        ))
                case .completed:
                    if let entry = vm.todayEntry {
                        TodayCompletedView(entry: entry, onEdit: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                vm.clearToday()
                            }
                        })
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: vm.todayState == .completed)

            // Save Ritual — kaydetme anında mood'a özgü animasyon
            if showRitual {
                ZStack {
                    // Arka plan tint
                    ritualColor.opacity(bgTinted ? bgTintLevel : 0)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.6), value: bgTinted)

                    GeometryReader { geo in
                        let maxDim = max(geo.size.width, geo.size.height)
                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                        // Vignette — kenarlarda kararma (gizemli)
                        if vignetteOpacity > 0 {
                            RadialGradient(
                                colors: [.clear, Color.black.opacity(vignetteOpacity)],
                                center: .center,
                                startRadius: geo.size.width * 0.25,
                                endRadius:   geo.size.width * 1.05
                            )
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                        }

                        // Işın demetleri — 8 ince çizgi (ışıklı)
                        if rayOpacity > 0 {
                            ZStack {
                                ForEach(0..<8, id: \.self) { i in
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.clear, ritualColor.opacity(0.45), .clear],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: maxDim, height: 1.5)
                                        .rotationEffect(.degrees(Double(i) * 22.5 + rayRotation))
                                }
                            }
                            .scaleEffect(rayScale)
                            .opacity(rayOpacity)
                            .position(center)
                            .allowsHitTesting(false)
                        }

                        // İkinci dalga halkası
                        if ring2Opacity > 0 {
                            Circle()
                                .stroke(ritualColor, lineWidth: 1.0)
                                .frame(width: maxDim * 2.9, height: maxDim * 2.9)
                                .scaleEffect(ring2Scale)
                                .opacity(ring2Opacity)
                                .position(center)
                                .allowsHitTesting(false)
                        }

                        // Sonar halkası (birinci)
                        if ringOpacity > 0 {
                            Circle()
                                .stroke(ritualColor, lineWidth: ringLineWidth)
                                .frame(width: maxDim * 2.6, height: maxDim * 2.6)
                                .scaleEffect(ringScale)
                                .opacity(ringOpacity)
                                .position(center)
                                .allowsHitTesting(false)
                        }

                        // Glow bloom — bulanık merkez parlaması
                        if glowOpacity > 0 {
                            Circle()
                                .fill(ritualColor.opacity(0.4))
                                .frame(width: maxDim * 1.1, height: maxDim * 1.1)
                                .blur(radius: 55)
                                .scaleEffect(burstScale)
                                .opacity(glowOpacity)
                                .position(center)
                                .allowsHitTesting(false)
                        }

                        // Solid fill burst
                        Circle()
                            .fill(ritualColor)
                            .frame(width: maxDim * 2.8, height: maxDim * 2.8)
                            .scaleEffect(burstScale)
                            .opacity(burstOpacity)
                            .position(center)
                            .allowsHitTesting(false)
                    }
                    .ignoresSafeArea()

                    // Katman 8 — Particle efektleri (en üstte)
                    if let mood = ritualMood {
                        SaveRitualParticles(mood: mood, color: ritualColor)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .onChange(of: vm.todayEntry) { _, newEntry in
            guard let entry = newEntry else { return }
            let mood = ONEMood(hex: entry.moodColorHex)
            triggerRitual(color: entry.moodColor, mood: mood)
            // Kayıt tamamlandı — step sıfırla ki tab bar görünsün
            entryStep = .search
        }
    }

    // swiftlint:disable function_body_length
    private func triggerRitual(color: Color, mood: ONEMood?) {
        // Sıfırla
        ritualColor      = color
        burstScale       = 0; burstOpacity    = 1
        ringScale        = 0; ringOpacity     = 0
        ring2Scale       = 0; ring2Opacity    = 0
        glowOpacity      = 0
        rayScale         = 0; rayOpacity      = 0; rayRotation = 0
        vignetteOpacity  = 0
        bgTinted         = false
        showRitual       = true
        ritualMood       = mood
        ONEHaptics.saveRitual(mood: mood)

        switch mood {

        case .atesli:
            // 🔴 Patlayıcı — sert yay + mini ikinci patlama + merkez glow
            ringLineWidth = 2.5; bgTintLevel = 0.14
            // Burst
            withAnimation(.spring(duration: 0.42, bounce: 0.28))              { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.28).delay(0.20))               { burstOpacity = 0 }
            // Glow bloom (burst ile birlikte parlar, hızla söner)
            withAnimation(.easeOut(duration: 0.30))                          { glowOpacity = 0.9 }
            withAnimation(.easeIn(duration: 0.25).delay(0.18))               { glowOpacity = 0 }
            // Ring 1 — ana halka
            withAnimation(.spring(duration: 0.78, bounce: 0.0).delay(0.04))  { ringScale = 1; ringOpacity = 0.85 }
            withAnimation(.easeIn(duration: 0.38).delay(0.48))               { ringOpacity = 0 }
            // Ring 2 — mini ikinci patlama (küçük gecikmeyle, daha hızlı)
            withAnimation(.spring(duration: 0.55, bounce: 0.0).delay(0.12))  { ring2Scale = 1; ring2Opacity = 0.55 }
            withAnimation(.easeIn(duration: 0.30).delay(0.55))               { ring2Opacity = 0 }
            // Tint
            withAnimation(.easeInOut(duration: 0.38).delay(0.10))            { bgTinted = true }
            scheduleCleanup(after: 0.98)

        case .enerjik:
            // 🟠 Sıçramalı — bounce ring + glow
            ringLineWidth = 2.0; bgTintLevel = 0.12
            withAnimation(.spring(duration: 0.50, bounce: 0.20))              { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.32).delay(0.24))               { burstOpacity = 0 }
            // Glow (orta yoğunluk)
            withAnimation(.easeOut(duration: 0.38))                          { glowOpacity = 0.7 }
            withAnimation(.easeIn(duration: 0.30).delay(0.22))               { glowOpacity = 0 }
            // Ring 1 bounce
            withAnimation(.spring(duration: 0.90, bounce: 0.06).delay(0.06)) { ringScale = 1; ringOpacity = 0.72 }
            withAnimation(.easeIn(duration: 0.45).delay(0.54))               { ringOpacity = 0 }
            // Ring 2 (daha küçük, kısa)
            withAnimation(.spring(duration: 0.65, bounce: 0.10).delay(0.14)) { ring2Scale = 1; ring2Opacity = 0.40 }
            withAnimation(.easeIn(duration: 0.35).delay(0.62))               { ring2Opacity = 0 }
            withAnimation(.easeInOut(duration: 0.42).delay(0.11))            { bgTinted = true }
            scheduleCleanup(after: 1.12)

        case .isikli:
            // 🟡 Yayılan ışık — glow + ışın demetleri
            ringLineWidth = 1.0; bgTintLevel = 0.16
            withAnimation(.easeOut(duration: 0.90))                          { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.52).delay(0.40))               { burstOpacity = 0 }
            // Güçlü glow bloom — güneş gibi
            withAnimation(.easeOut(duration: 0.70))                          { glowOpacity = 1.0 }
            withAnimation(.easeIn(duration: 0.55).delay(0.55))               { glowOpacity = 0 }
            // Ring
            withAnimation(.easeOut(duration: 1.40).delay(0.08))              { ringScale = 1; ringOpacity = 0.50 }
            withAnimation(.easeIn(duration: 0.65).delay(0.85))               { ringOpacity = 0 }
            // Işın demetleri — yavaş çıkar, hafif döner, solar
            withAnimation(.easeOut(duration: 0.80).delay(0.10))              { rayScale = 1; rayOpacity = 0.75 }
            withAnimation(.linear(duration: 1.50).delay(0.10))               { rayRotation = 18 }
            withAnimation(.easeIn(duration: 0.55).delay(0.90))               { rayOpacity = 0 }
            withAnimation(.easeInOut(duration: 0.65).delay(0.10))            { bgTinted = true }
            scheduleCleanup(after: 1.65)

        case .sakin:
            // 🟢 Nefes gibi — yavaş glow + sessiz halka
            ringLineWidth = 0.8; bgTintLevel = 0.08
            withAnimation(.easeInOut(duration: 1.10))                        { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.60).delay(0.50))               { burstOpacity = 0 }
            // Yumuşak glow (düşük yoğunluk, yavaş solar)
            withAnimation(.easeInOut(duration: 0.90))                        { glowOpacity = 0.45 }
            withAnimation(.easeIn(duration: 0.65).delay(0.45))               { glowOpacity = 0 }
            // İnce halka
            withAnimation(.easeInOut(duration: 1.50).delay(0.15))            { ringScale = 1; ringOpacity = 0.42 }
            withAnimation(.easeIn(duration: 0.70).delay(0.92))               { ringOpacity = 0 }
            withAnimation(.easeInOut(duration: 0.70).delay(0.15))            { bgTinted = true }
            scheduleCleanup(after: 1.85)

        case .derin:
            // 🔵 Su damlası — iki konsantrik halka + glow
            ringLineWidth = 1.5; bgTintLevel = 0.10
            withAnimation(.spring(duration: 0.72, bounce: 0.0))              { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.42).delay(0.30))               { burstOpacity = 0 }
            // Yumuşak glow
            withAnimation(.easeOut(duration: 0.60))                          { glowOpacity = 0.55 }
            withAnimation(.easeIn(duration: 0.50).delay(0.30))               { glowOpacity = 0 }
            // İlk dalga
            withAnimation(.spring(duration: 1.00, bounce: 0.0).delay(0.10)) { ringScale = 1; ringOpacity = 0.62 }
            withAnimation(.easeIn(duration: 0.55).delay(0.65))               { ringOpacity = 0 }
            // İkinci dalga (daha dıştaki halka)
            withAnimation(.spring(duration: 1.25, bounce: 0.0).delay(0.30)) { ring2Scale = 1; ring2Opacity = 0.35 }
            withAnimation(.easeIn(duration: 0.60).delay(0.95))               { ring2Opacity = 0 }
            withAnimation(.easeInOut(duration: 0.60).delay(0.12))            { bgTinted = true }
            scheduleCleanup(after: 1.75)

        case .gizemli:
            // 🟣 Ağır belirir — vignette kenar kararması + glow
            ringLineWidth = 1.0; bgTintLevel = 0.09
            withAnimation(.easeInOut(duration: 1.05))                        { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.58).delay(0.48))               { burstOpacity = 0 }
            // Glow (orta, yavaş solar)
            withAnimation(.easeInOut(duration: 0.80))                        { glowOpacity = 0.60 }
            withAnimation(.easeIn(duration: 0.60).delay(0.50))               { glowOpacity = 0 }
            // Vignette — kenarlarda kararır, belirir, yavaş solar
            withAnimation(.easeInOut(duration: 0.70).delay(0.05))            { vignetteOpacity = 0.30 }
            withAnimation(.easeIn(duration: 0.80).delay(0.85))               { vignetteOpacity = 0 }
            // Halka
            withAnimation(.spring(duration: 1.45, bounce: 0.0).delay(0.20)) { ringScale = 1; ringOpacity = 0.48 }
            withAnimation(.easeIn(duration: 0.62).delay(0.95))               { ringOpacity = 0 }
            withAnimation(.easeInOut(duration: 0.72).delay(0.15))            { bgTinted = true }
            scheduleCleanup(after: 1.82)

        case .bos:
            // ⚫️ Minimal — sadece karanlık dalga, efekt yok
            bgTintLevel = 0.06
            withAnimation(.easeInOut(duration: 1.20))                        { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.80).delay(0.40))               { burstOpacity = 0 }
            withAnimation(.easeInOut(duration: 0.80).delay(0.10))            { bgTinted = true }
            scheduleCleanup(after: 1.45)

        case .taze:
            // 🟢 Tazelenme — hafif sıçrama + yeşil ışık
            ringLineWidth = 1.2; bgTintLevel = 0.12
            withAnimation(.spring(duration: 0.55, bounce: 0.18))             { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.35).delay(0.26))               { burstOpacity = 0 }
            withAnimation(.easeOut(duration: 0.42))                          { glowOpacity = 0.55 }
            withAnimation(.easeIn(duration: 0.32).delay(0.26))               { glowOpacity = 0 }
            withAnimation(.spring(duration: 0.95, bounce: 0.04).delay(0.07)) { ringScale = 1; ringOpacity = 0.70 }
            withAnimation(.easeIn(duration: 0.50).delay(0.56))               { ringOpacity = 0 }
            withAnimation(.easeInOut(duration: 0.45).delay(0.10))            { bgTinted = true }
            scheduleCleanup(after: 1.20)

        case .ozgur:
            // 🩵 Açılım — geniş yayılan halka + ferah glow
            ringLineWidth = 1.0; bgTintLevel = 0.11
            withAnimation(.easeOut(duration: 0.75))                          { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.48).delay(0.36))               { burstOpacity = 0 }
            withAnimation(.easeOut(duration: 0.50))                          { glowOpacity = 0.60 }
            withAnimation(.easeIn(duration: 0.40).delay(0.32))               { glowOpacity = 0 }
            withAnimation(.spring(duration: 1.10, bounce: 0.0).delay(0.05))  { ringScale = 1; ringOpacity = 0.65 }
            withAnimation(.easeIn(duration: 0.60).delay(0.60))               { ringOpacity = 0 }
            withAnimation(.easeInOut(duration: 0.52).delay(0.12))            { bgTinted = true }
            scheduleCleanup(after: 1.55)

        case .nostaljik:
            // 🔵 Dalga belirişi — konsantrik çift halka, yavaş söner
            ringLineWidth = 1.2; bgTintLevel = 0.10
            withAnimation(.easeOut(duration: 0.80))                          { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.50).delay(0.40))               { burstOpacity = 0 }
            withAnimation(.easeOut(duration: 0.45))                          { glowOpacity = 0.50 }
            withAnimation(.easeIn(duration: 0.38).delay(0.30))               { glowOpacity = 0 }
            withAnimation(.spring(duration: 1.15, bounce: 0.0).delay(0.06))  { ringScale = 1; ringOpacity = 0.70 }
            withAnimation(.easeIn(duration: 0.65).delay(0.62))               { ringOpacity = 0 }
            withAnimation(.spring(duration: 0.85, bounce: 0.0).delay(0.20))  { ring2Scale = 1; ring2Opacity = 0.35 }
            withAnimation(.easeIn(duration: 0.45).delay(0.72))               { ring2Opacity = 0 }
            withAnimation(.easeInOut(duration: 0.60).delay(0.14))            { bgTinted = true }
            scheduleCleanup(after: 1.70)

        case .hassas:
            // 🩷 Yumuşak pulsasyon — zarif glow, ince halka
            ringLineWidth = 0.8; bgTintLevel = 0.09
            withAnimation(.easeOut(duration: 0.85))                          { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.55).delay(0.38))               { burstOpacity = 0 }
            withAnimation(.easeOut(duration: 0.55))                          { glowOpacity = 0.65 }
            withAnimation(.easeIn(duration: 0.48).delay(0.35))               { glowOpacity = 0 }
            withAnimation(.spring(duration: 1.20, bounce: 0.0).delay(0.08))  { ringScale = 1; ringOpacity = 0.60 }
            withAnimation(.easeIn(duration: 0.70).delay(0.65))               { ringOpacity = 0 }
            withAnimation(.easeInOut(duration: 0.65).delay(0.14))            { bgTinted = true }
            scheduleCleanup(after: 1.65)

        case .temiz:
            // ⬜️ Net, sade — hızlı burst, halka yok, efekt yok
            bgTintLevel = 0.07
            withAnimation(.spring(duration: 0.50, bounce: 0.0))              { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.30).delay(0.22))               { burstOpacity = 0 }
            withAnimation(.easeInOut(duration: 0.40).delay(0.10))            { bgTinted = true }
            scheduleCleanup(after: 0.88)

        default:
            // Fallback
            ringLineWidth = 1.5; bgTintLevel = 0.11
            withAnimation(.spring(duration: 0.60, bounce: 0.05))             { burstScale = 1 }
            withAnimation(.easeIn(duration: 0.38).delay(0.28))               { burstOpacity = 0 }
            withAnimation(.easeOut(duration: 0.40))                          { glowOpacity = 0.6 }
            withAnimation(.easeIn(duration: 0.35).delay(0.28))               { glowOpacity = 0 }
            withAnimation(.spring(duration: 1.05, bounce: 0.0).delay(0.08)) { ringScale = 1; ringOpacity = 0.65 }
            withAnimation(.easeIn(duration: 0.55).delay(0.60))               { ringOpacity = 0 }
            withAnimation(.easeInOut(duration: 0.55).delay(0.12))            { bgTinted = true }
            scheduleCleanup(after: 1.40)
        }
    }
    // swiftlint:enable function_body_length

    private func scheduleCleanup(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.35)) {
                bgTinted   = false
                showRitual = false
            }
            // Particle view'ı fade-out animasyonu bittikten sonra temizle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                ritualMood = nil
            }
        }
    }
}

#Preview {
    TodayView(context: PersistenceController.preview.container.viewContext, entryStep: .constant(.search))
}
