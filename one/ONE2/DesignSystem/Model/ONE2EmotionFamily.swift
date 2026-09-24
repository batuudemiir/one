//
//  ONE2EmotionFamily.swift
//  ONE 2.0
//
//  Sekiz duygu ailesi (tokens.json `emo-*`). Ham değerler kalıcı ID'dir
//  (küçük harf, ASCII); duygu ID'leri bunun üstüne kurulur ("nese.minnettar").
//

import SwiftUI

nonisolated enum ONE2EmotionFamily: String, CaseIterable, Hashable, Sendable {
    case nese, huzur, enerji, sevgi, kaygi, huzun, ofke, yorgun

    var title: String { one2String("one2.emotion.family.\(rawValue)") }
}

@MainActor
extension ONE2EmotionFamily {

    var fill: Color {
        switch self {
        case .nese:   return ONE2Color.emoNese
        case .huzur:  return ONE2Color.emoHuzur
        case .enerji: return ONE2Color.emoEnerji
        case .sevgi:  return ONE2Color.emoSevgi
        case .kaygi:  return ONE2Color.emoKaygi
        case .huzun:  return ONE2Color.emoHuzun
        case .ofke:   return ONE2Color.emoOfke
        case .yorgun: return ONE2Color.emoYorgun
        }
    }

    var onFill: Color {
        switch self {
        case .nese:   return ONE2Color.onEmoNese
        case .huzur:  return ONE2Color.onEmoHuzur
        case .enerji: return ONE2Color.onEmoEnerji
        case .sevgi:  return ONE2Color.onEmoSevgi
        case .kaygi:  return ONE2Color.onEmoKaygi
        case .huzun:  return ONE2Color.onEmoHuzun
        case .ofke:   return ONE2Color.onEmoOfke
        case .yorgun: return ONE2Color.onEmoYorgun
        }
    }
}
