//
//  ONEFormatters.swift
//  one
//
//  Paylaşılan `DateFormatter` havuzu.
//
//  Neden: kod tabanında 80'den fazla `DateFormatter()` allocation'ı vardı ve
//  **tek bir** `static let` formatter yoktu. Bunların bir kısmı satır başına
//  çalışıyordu — hub'daki her an, Çevre'deki her arkadaş kartı, arşivin yıl
//  görünümündeki 12 ay adı. `DateFormatter` kurulumu ucuz değil: `dateFormat`
//  ataması ICU pattern parse'ı tetikliyor ve bu iş kaydırma sırasında her
//  karede tekrarlanıyordu.
//
//  Neden düz `static let` değil: format'ların çoğu
//  `LanguageManager.shared.currentLocale` kullanıyor. Uygulama içi dil
//  değişimi (`LanguageManager.refreshToken`) mümkün olduğu için sabit bir
//  formatter bayat locale ile takılı kalırdı. Havuz locale kimliğini izliyor;
//  dil değişince kendini bir kez boşaltıyor.
//

import Foundation

enum ONEFormatters {

    // MARK: - Locale'den bağımsız

    /// `HH:mm` — an saati. 24 saat biçimi bilinçli: kullanıcının bölgesel
    /// ayarına göre değişmemesi gereken sabit bir sunum.
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    /// `yyyy-MM-dd` — gün anahtarı. Ekrana çıkmıyor; `UserDefaults` anahtarı
    /// üretiyor, o yüzden POSIX'e sabit. Cihaz locale'i Arap-Hint rakamları
    /// kullandığında anahtarın biçimi sessizce değişirdi.
    static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - El yazısı damgası (her dilde İngilizce)

    // El yazısı tarih çevrilmiyor. Bir metin değil, fotoğrafa basılan bir
    // **damga** — filmin kenarındaki tarih gibi. Dokuz dilin hepsinde aynı
    // görünüyor, çünkü:
    //
    //  1. `CaveatBrush-Regular` Kiril ve CJK taşımıyor. Yerelleştirilseydi
    //     Rusça/Japonca/Korece/Çince'de tofu kutucuk çıkardı.
    //  2. Damganın işi bilgi vermek değil, kartı tarihlemek. Yerelleştirilmiş
    //     tarih zaten mono altyazıda ve VoiceOver label'ında var.
    //
    // **Kural:** bu iki formatter'ın çıktısı ekranda görünür ama asla
    // erişilebilirlik metni olarak kullanılmaz. `V3HandText` el yazısını
    // VoiceOver'dan gizliyor; okunacak tarih `dayMonth` üzerinden gelir.

    /// `MMM d` — "Aug 17". Gün seviyesindeki yüzeyler.
    static let handDayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()

    /// `MMMM` — "August". Ay seviyesindeki yüzeyler (arşiv başlığı).
    static let handMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM"
        return f
    }()

    // MARK: - Locale'e bağlı

    /// `d MMMM` — "17 Ağustos"
    static var dayMonth: DateFormatter { localized("d MMMM") }
    /// `d MMMM · EEEE` — "17 Ağustos · Pazar"
    static var dayMonthWeekday: DateFormatter { localized("d MMMM · EEEE") }
    /// `MMMM` — "Ağustos"
    static var monthName: DateFormatter { localized("MMMM") }
    /// `MMM` — "Ağu" (yıl ızgarasındaki kısa ay)
    static var monthShort: DateFormatter { localized("MMM") }
    /// `MMMM yyyy` — "Ağustos 2026"
    static var monthYear: DateFormatter { localized("MMMM yyyy") }
    /// `LLLL` — tek başına ay adı (bazı dillerde `MMMM`'den farklı çekimlenir)
    static var monthStandalone: DateFormatter { localized("LLLL") }
    /// `EEEE` — "Pazar". Gün detayının meta satırı.
    ///
    /// `dayMonthWeekday` zaten vardı ama tarihi de taşıyor ("17 Ağustos ·
    /// Pazar"); gün detayında tarih başlıkta duruyor, meta satırına yalnız
    /// haftanın günü kalıyor.
    static var weekday: DateFormatter { localized("EEEE") }

    // MARK: - Havuz

    private static let lock = NSLock()
    private static var cache: [String: DateFormatter] = [:]
    private static var cachedLocaleID: String?

    /// Verilen pattern için paylaşılan formatter. Locale değiştiyse havuz
    /// bir kez boşaltılır — böylece dil değişimi sonrası ilk okuma taze
    /// formatter kurar, sonrakiler onu paylaşır.
    private static func localized(_ pattern: String) -> DateFormatter {
        let locale = LanguageManager.shared.currentLocale
        lock.lock()
        defer { lock.unlock() }

        if cachedLocaleID != locale.identifier {
            cache.removeAll()
            cachedLocaleID = locale.identifier
        }
        if let existing = cache[pattern] { return existing }

        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = pattern
        cache[pattern] = f
        return f
    }
}
