//
//  OneActivityExtensionBundle.swift
//  OneActivityExtension
//

import WidgetKit
import SwiftUI

@main
struct OneActivityExtensionBundle: WidgetBundle {
    var body: some Widget {
        DailySongLiveActivity()
        FriendShareLiveActivity()
    }
}
