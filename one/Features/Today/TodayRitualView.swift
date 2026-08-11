//
//  TodayRitualView.swift
//  one
//

import SwiftUI

struct TodayRitualView: View {
    @ObservedObject var vm: TodayViewModel
    @StateObject private var coordinator: TodayCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - backfillDate: verilirse ritüel doğrudan o geçmiş gün için telafi
    ///     modunda açılır (bugün zaten doluyken kullanılır).
    ///   - onFinish: telafi oturumu bitince (kayıt ya da vazgeçme) çağrılır.
    ///     Sheet olarak sunulduğunda kapanmayı bu tetikler.
    init(vm: TodayViewModel, backfillDate: Date? = nil, onFinish: (() -> Void)? = nil) {
        self.vm = vm
        let coordinator = TodayCoordinator(vm: vm)
        coordinator.backfillDate = backfillDate
        coordinator.onFinish = onFinish
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        ZStack {
            ONEBrand.bone.ignoresSafeArea()

            // Üst çubuk artık `.overlay` DEĞİL, düzenin içinde. Overlay
            // olduğu için adımın üstünü örtüyordu: "bugün ne renktin?"
            // çubuğun altında kalıyor, kadran da kalan yeri bilmeden
            // ölçekleniyordu. Akışta durunca içerik kendiliğinden sığıyor.
            VStack(spacing: 0) {
                topBar

                Group {
                    switch coordinator.step {
                    case .mood:
                        MoodStepView(coordinator: coordinator)
                            .transition(stepTransition(insertion: .trailing, removal: .leading))
                    case .song:
                        SongStepView(coordinator: coordinator, vm: vm)
                            .transition(stepTransition(insertion: .trailing, removal: .leading))
                    }
                }
                .animation(reduceMotion ? .none : .easeOut(duration: 0.22), value: coordinator.step)
                .frame(maxHeight: .infinity)
            }
        }
        .gesture(
            coordinator.step.rawValue > 0
                ? DragGesture(minimumDistance: 40, coordinateSpace: .local)
                    .onEnded { v in
                        if v.translation.width > 60 && abs(v.translation.height) < abs(v.translation.width) {
                            coordinator.back()
                        }
                    }
                : nil
        )
        .onAppear { coordinator.vm = vm } // Ensures vm reference stays fresh on re-appear
    }

    /// Prototipin `.rit-top`'u: solda geri, ortada adım noktaları, sağda
    /// sayaç. Buradan çıkanlar (hepsi prototipte yok, hepsi dikey yer
    /// yiyordu ve ritüelin tek işi olmasını bozuyordu):
    ///  • ✕ — sekme çubuğu artık görünür, çıkış yolu zaten orada. Yalnız
    ///    telafi sheet'inde (dock yokken) gösteriliyor.
    ///  • Haftalık ritim — bugünü doldururken geçmiş günleri sunmak
    ///    dikkati dağıtıyor. Telafi hâlâ "kaydedildi" ekranından ve
    ///    geri dönüş ekranından açılabiliyor.
    ///  • Bağlam hapı — iki adımlık bir akışta az önce seçtiğini
    ///    tekrar göstermek; geri oku aynı işi yapıyor.
    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                let showsBack  = coordinator.step.rawValue > 0
                let showsClose = !showsBack && coordinator.onFinish != nil

                Button {
                    if showsBack { coordinator.back() } else { coordinator.onFinish?() }
                } label: {
                    Image(systemName: showsBack ? "chevron.left" : "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(V3Tokens.mutedText)
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .opacity(showsBack || showsClose ? 1 : 0)
                .disabled(!(showsBack || showsClose))
                .accessibilityLabel(showsBack ? "Geri" : "Kapat")

                Spacer()

                RitualProgressDots(
                    current: coordinator.step.rawValue,
                    total: RitualStep.allCases.count
                )

                Spacer()

                Text("\(coordinator.step.rawValue + 1) / \(RitualStep.allCases.count)")
                    .monoLabel(tracking: 1.3)
                    .foregroundColor(V3Tokens.faintText)
                    .frame(width: 44, alignment: .trailing)
            }

            // Telafi modunda hangi günü doldurduğun net olsun.
            if let date = coordinator.backfillDate {
                backfillBanner(date)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
    }

    /// Telafi modu göstergesi — suçlayıcı değil, bilgilendirici.
    /// "Kaçırdın" demez; hangi günü doldurduğunu söyler ve çıkış yolu bırakır.
    private func backfillBanner(_ date: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(V3Tokens.mutedText)

            Text("\(weekdayName(date)) gününü dolduruyorsun")
                .bodyXS()
                .foregroundColor(V3Tokens.ink)

            Spacer(minLength: 0)

            Button {
                coordinator.cancelBackfill()
            } label: {
                Text("vazgeç")
                    .monoLabel(tracking: 0.4)
                    .foregroundColor(V3Tokens.mutedText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(V3Tokens.surface.opacity(0.55))
        )
        .accessibilityElement(children: .combine)
    }

    private func weekdayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    private func stepTransition(insertion: Edge, removal: Edge) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: insertion).combined(with: .opacity),
                removal: .move(edge: removal).combined(with: .opacity)
            )
    }
}
