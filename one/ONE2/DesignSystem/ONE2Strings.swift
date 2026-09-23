//
//  ONE2Strings.swift
//  ONE 2.0
//
//  ONE 2.0 arayüz dizeleri ayrı bir tabloda: `ONE2.strings`
//  (one/ONE2/DesignSystem/Strings/<dil>.lproj/). Uygulamanın ortak
//  `Localizable.strings`'i UX oturumunun sahipliğinde değil; ayrı tablo
//  iki oturumun aynı dosyada çakışmasını da önler.
//
//  Şimdilik yalnız tr ve en (CLAUDE.md istisnası); diğer 7 dil relaunch
//  öncesi ayrı bir iş.
//

import Foundation

enum ONE2Strings {
    static let table = "ONE2"
}

/// `ONE2` tablosundan yerelleştirilmiş dize.
func one2String(_ key: String) -> String {
    NSLocalizedString(key, tableName: ONE2Strings.table, comment: "")
}
