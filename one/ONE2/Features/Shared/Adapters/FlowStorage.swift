//
//  FlowStorage.swift
//  ONE 2.0
//
//  Yazı ve akış taslaklarının cihazdaki deposu: App Group (widget da okur).
//

import Foundation

enum FlowStorage {
    static let appGroup = "group.com.batudemir.ones"
    static var backing: KeyValueBacking { UserDefaults(suiteName: appGroup) ?? .standard }
}
