//
//  View+ONE.swift
//  one
//
//  Design System — ekran kabuğu.
//
//  Bu dosya bir "yardımcılar çantası" değil: ONE'ın her ekranının paylaştığı
//  **üç karar** burada yaşıyor — zemin, kanal, başlık. Bir ekran bunları
//  kendi yazdığı anda uygulama iki uygulamaya bölünüyor.
//
//  Önceki hâli on modifier içeriyordu ve **hiçbirinin çağrısı yoktu**
//  (`primaryText`, `cardBackground`, `standardHorizontalPadding`, …). Ölü
//  olmaları asıl sorun değildi; yanlış olmaları sorundu:
//
//  - `mutedText()` metin rengi olarak `V3Tokens.wash` döndürüyordu — wash bir
//    *zemin* rengi, metin olarak kontrastı 1.1:1.
//  - `tertiaryText()` ile `secondaryText()` aynı rengi döndürüyordu, yani
//    isimlerinin vaat ettiği hiyerarşi yoktu.
//  - `standardHorizontalPadding()` 26pt veriyordu; ONE'ın içerik kanalı
//    `V3Tokens.channel` = 24pt. Bu API'yi bulan bir sonraki ekran markanın
//    kenar hattından 2pt kaymış olarak doğacaktı.
//

import SwiftUI

// MARK: - Ekran kabuğu

extension View {

    /// **Kök sekme gövdesi.** Zemin + içerik kanalı, tek yerden.
    ///
    /// ONE'ın sol kenar hattı 24pt (`V3Tokens.channel`). Bugün ekranlar bu
    /// hattı elle yazıyor ve beş farklı sayı kullanıyor — 20 (42 çağrı),
    /// 24 (34), 22 (14), 18 (15), 16 (12). Tek tek hiçbiri fark edilmiyor;
    /// sekme değiştirirken hepsi birden fark ediliyor.
    ///
    /// Yatay pay burada, dikey pay çağıranda: ekranların üst boşluğu
    /// `safeAreaInset` ile üst çubuktan geliyor, tek sayıya indirilemez.
    func oneScreenBody() -> some View {
        self
            .padding(.horizontal, V3Tokens.channel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// **Ekran zemini.** `paper`, safe area dahil.
    ///
    /// `.background(Color(UIColor.systemBackground))` ile arasındaki fark
    /// koyu temada görünür: sistem zemini saf siyaha (#000) giderken ONE'ın
    /// zemini #0C0C10 — mavi tarafa çalan, kağıt hissini koruyan bir koyu.
    func oneScreenGround() -> some View {
        self.background(V3Tokens.paper.ignoresSafeArea())
    }

    /// Kök sekme kabuğu: zemin + kanal birlikte.
    func oneScreen() -> some View {
        self.oneScreenBody().oneScreenGround()
    }
}

// MARK: - Başlık rolleri
//
// Boyutlar `ONETypography` ölçeğinden geliyor; buradakiler o ölçeğe **rol**
// adı veriyor. Neden gerekli: bugün başlıklar ham çağrıyla yazılıyor ve
// `sans` ailesi 21 ayrı punto kullanıyor (10.5, 11, 11.5, 12, 12.5, 13,
// 13.5, 14, 14.5, 15, 16, 17, 18, 19, 20, 21, 23, 24, 32 …) — markanın
// tanımladığı beş kademe yerine. Ölçek dışına çıkmak serbest olmalı ama
// *kasıtlı* olmalı; kolay yol ölçeğin içinde kalmalı.

extension View {

    /// Ekran başlığı — Archivo, 30pt. Kök sekmelerin en üst başlığı.
    func oneScreenTitle() -> some View {
        self.displayLG().foregroundColor(V3Tokens.ink)
    }

    /// Sayfa / modal başlığı — Archivo, 24pt. Sheet ve alt ekran başlıkları.
    func onePageTitle() -> some View {
        self.displayMD().foregroundColor(V3Tokens.ink)
    }

    /// Bölüm başlığı — Archivo, 22pt. Ekran içi gruplar.
    func oneSectionTitle() -> some View {
        self.displayLgAlt().foregroundColor(V3Tokens.ink)
    }

    /// Kart başlığı — Archivo, 20pt.
    func oneCardTitle() -> some View {
        self.displaySM().foregroundColor(V3Tokens.ink)
    }

    /// Bölüm üstü mikro etiket — mono, büyük harf, tracking'li.
    /// v3'ün her ekranda tekrar eden "kapsam" satırı.
    func oneEyebrow() -> some View {
        self.v3MicroLabel().foregroundColor(V3Tokens.faintText)
    }
}

// MARK: - Yüzeyler

extension View {

    /// Kart yüzeyi — `surface` dolgu + saç teli kenar + kart yarıçapı.
    ///
    /// Kenar çizgisi opsiyonel değil: v3'ün kağıt estetiğinde kartı zeminden
    /// ayıran şey gölge değil, 1pt'lik neredeyse görünmez bir hat. Kontrastı
    /// artıran kullanıcıda `hairline` gerçek bir çizgiye dönüyor —
    /// `V3Tokens.hairline` bunu kendisi hallediyor.
    func oneCardBackground(radius: CGFloat = V3Tokens.radiusCard) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(V3Tokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(V3Tokens.hairline, lineWidth: 1)
            )
    }
}

// MARK: - v3 ekran girişi

extension View {

    /// v3 `prrise` — 9px translateY + opacity fade, 0.32s cubic-bezier(.2,.9,.25,1).
    /// Ekran girerken bir kez. Reduce Motion'a saygılı.
    func prrise() -> some View {
        modifier(PrriseEntranceModifier())
    }
}

private struct PrriseEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 9)
            .onAppear {
                withAnimation(ONEAnimation.easingSaved) { shown = true }
            }
    }
}
