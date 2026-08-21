//
//  ScreenType.swift
//  one
//
//  Kabuğun gidebileceği ekranlar.
//

import SwiftUI

/// Kabuğun aktif ekranı.
///
/// Dördü dock sekmesi (`PrimaryTab`), `echo` ise sekme değil — Profil'deki
/// aylık özet kartından sheet olarak açılıyor.
///
/// Buradan kalkanlar: `.confirm`, `.done`, `.search`. Üçü v2 ritüelinin
/// (renk → şarkı ara → onayla → bitti) adımlarıydı; v3'te akış
/// `V3EntryContainer` içinde tek ekrana indi. `.confirm` zaten hiçbir yerde
/// atanmıyordu, dolayısıyla `.search` ve `.done` de ulaşılamazdı.
enum ScreenType {
    case today
    case archive
    case profile
    case circle
    case echo
}
