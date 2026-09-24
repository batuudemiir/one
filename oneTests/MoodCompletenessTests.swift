//
//  MoodCompletenessTests.swift
//  oneTests
//
//  Property-Based Tests — mood tablosunun eksiksizliği.
//
//  Eskiden `ONEMood` (12 case) üzerindeydi ve onun sunum üyelerini
//  (`color`, `waveHeight`, `gradientStops`…) doğruluyordu. O üyeler
//  kaldırıldı: `ONEMood` artık bir seçici değil, yalnızca eski kayıtların
//  hex'ini çözen göç katmanı. Testin fikri değerli olduğu için kanonik
//  enum'a (`V3Mood`) taşındı.
//

import Testing
import SwiftUI
@testable import OneDailyBatuhan

/// Property: Mood Completeness
///
/// `V3Mood`'daki her duygu, kendisini çizmek için gereken **her** özelliği
/// sağlamalı. Bir case eklenip tablolardan birine yazılmayı unutmak bu
/// enum'ın tarihindeki en sık hata biçimiydi (pastel tablo doygun tablodan
/// geride kalıyordu); `allCases` üzerinden dönmek onu derleme değil test
/// zamanında yakalıyor.
struct MoodCompletenessTests {

    /// Palet 9 duygudan oluşur — 3×3 ızgara (satır: enerji, sütun: yön).
    /// Sayı değişiyorsa `V3ColorStepView` ızgarası da yeniden dengelenmeli.
    @Test("Palet tam olarak 9 duygu içeriyor")
    func testMoodCount() {
        #expect(V3Mood.allCases.count == 9)
    }

    @Test("Her mood'un geçerli bir hex'i var")
    func testAllMoodsHaveValidHex() {
        for mood in V3Mood.allCases {
            let hex = mood.hex
            #expect(hex.hasPrefix("#"), "\(mood.rawValue): hex '#' ile başlamalı")
            #expect(hex.count == 7, "\(mood.rawValue): hex 7 karakter olmalı, \(hex.count)")
            let digits = hex.dropFirst()
            #expect(
                digits.allSatisfy { $0.isHexDigit },
                "\(mood.rawValue): hex geçersiz karakter içeriyor — \(hex)"
            )
        }
    }

    @Test("Her mood'un okunabilir bir ink hex'i var")
    func testAllMoodsHaveValidInkHex() {
        for mood in V3Mood.allCases {
            let hex = mood.inkHex
            #expect(hex.hasPrefix("#"), "\(mood.rawValue): inkHex '#' ile başlamalı")
            #expect(hex.count == 7, "\(mood.rawValue): inkHex 7 karakter olmalı")
        }
    }

    /// Hex tablosu benzersiz olmalı: iki duygu aynı rengi taşırsa
    /// `fromHex` biri lehine sessizce karar verir ve diğeri arşivde kaybolur.
    @Test("Mood renkleri benzersiz")
    func testMoodColorsAreUnique() {
        let hexes = V3Mood.allCases.map { $0.hex.uppercased() }
        #expect(Set(hexes).count == hexes.count, "Yinelenen mood rengi var: \(hexes)")
    }

    @Test("Her mood'un boş olmayan bir etiketi var")
    func testAllMoodsHaveLabel() {
        for mood in V3Mood.allCases {
            #expect(!mood.label.isEmpty, "\(mood.rawValue): label boş")
            // Katalog anahtarı çözülmediyse NSLocalizedString anahtarın
            // kendisini döndürür — bu da bir eksiklik.
            #expect(
                mood.label != "mood.v3.\(mood.rawValue).label",
                "\(mood.rawValue): label katalogda yok"
            )
        }
    }

    @Test("Her mood'un boş olmayan bir anlamı var")
    func testAllMoodsHaveMeaning() {
        for mood in V3Mood.allCases {
            #expect(!mood.meaning.isEmpty, "\(mood.rawValue): meaning boş")
            #expect(
                mood.meaning != "mood.v3.\(mood.rawValue).meaning",
                "\(mood.rawValue): meaning katalogda yok"
            )
        }
    }

    /// `fromHex` kendi tablosunu tam olarak geri çözebilmeli. Bu roundtrip
    /// kırılırsa renk seçicide seçilen duygu, kaydedilip geri okunduğunda
    /// başka bir duygu olarak görünür.
    @Test("hex → fromHex roundtrip her mood için kimliği koruyor")
    func testHexRoundTrip() {
        for mood in V3Mood.allCases {
            #expect(
                V3Mood.fromHex(mood.hex) == mood,
                "\(mood.rawValue): \(mood.hex) kendisine geri çözülmüyor"
            )
        }
    }

    /// `closest` hiçbir zaman nil dönmemeli (geçerli bir hex verildiğinde) —
    /// istatistik yüzeylerinin "?" kovası olmamasının garantisi bu.
    @Test("closest geçerli hex için her zaman bir mood döndürüyor")
    func testClosestAlwaysResolves() {
        for hex in ["#000000", "#FFFFFF", "#123456", "#ABCDEF", "#7F7F7F"] {
            #expect(V3Mood.closest(toHex: hex) != nil, "\(hex): closest nil döndü")
        }
    }
}
