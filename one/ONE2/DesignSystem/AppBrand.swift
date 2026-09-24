//
//  AppBrand.swift
//  ONE 2.0
//
//  Marka adı tek yerde (07 §0). Ad henüz kesin değil; kopyada ve kodda
//  hiçbir metne elle yazılmaz. Dizeler adı `%@` ile alır:
//  `String(format: one2String("…"), AppBrand.name)`.
//

nonisolated enum AppBrand {
    static let name = "ONE"
    /// Premium katman adı ("ONE+").
    static var plusName: String { name + "+" }
}
