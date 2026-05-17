//
//  CameraState.swift
//  one
//
//  Plain ObservableObject — no @MainActor, updates always on main thread.
//  Extracted from CameraView.swift as part of Faz 3 decomposition.
//

import SwiftUI
import Combine

final class CameraState: ObservableObject {
    @Published var flash:     CameraFlash      = .off
    @Published var delay:     CaptureDelayMode
    @Published var grid:      Bool
    @Published var filmPreset: FilmPreset
    @Published var zoom:       CGFloat          = 1.0
    @Published var minZoom:    CGFloat          = 1.0
    @Published var maxZoom:    CGFloat          = 12.0
    /// Actual AVFoundation zoom factors + display labels for each lens (0.5×, 1×, 3× …)
    @Published var lensPresets: [(factor: CGFloat, label: String)] = [(1.0, "1×")]
    @Published var isLocked:  Bool             = false
    @Published var exposure:  Float            = 0
    @Published var minExp:    Float            = -2
    @Published var maxExp:    Float            = 2
    @Published var showExp:   Bool             = false
    @Published var counting:  Bool             = false
    @Published var capturing: Bool             = false
    @Published var pinching:  Bool             = false
    @Published var isFront:   Bool             = false
    @Published var flashOK:            Bool             = false
    /// Shutter disabled briefly after returning from preview (prevents accidental re-shoot)
    @Published var isInRetakeCooldown: Bool             = false
    @Published var isDismissing: Bool                   = false
    @Published var pitch:     Double           = 0
    @Published var focusPt:   CGPoint?         = nil   // screen-space tap point for exposure handle
    /// Base focal length of the wide lens in mm (set by CameraVC)
    @Published var baseFocalMM: CGFloat         = 26
    /// Wide-lens zoom factor (switchOverVideoZoomFactors[0] or 1.0 for single-camera)
    @Published var wideZoomFactor: CGFloat       = 1.0
    /// Computed focal length label based on current zoom
    var focalLengthLabel: String {
        let effectiveMM = baseFocalMM * (zoom / wideZoomFactor)
        return "\(Int(round(effectiveMM)))mm"
    }
    /// Device model name (e.g. "iPhone 16 Pro")
    var deviceModelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let id = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        // Common mappings
        let map: [String: String] = [
            "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus",
            "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
            "arm64": "Simulator"
        ]
        return map[id] ?? id
    }

    // Commands wired up by CameraVC
    var onShoot:    (() -> Void)?
    var onFlip:     (() -> Void)?
    var onSetZoom:  ((CGFloat) -> Void)?
    var onSetExp:   ((Float) -> Void)?

    private let ud = UserDefaults.standard

    init() {
        delay = CaptureDelayMode(rawValue: ud.integer(forKey: "cam.delay")) ?? .off
        grid  = ud.object(forKey: "cam.grid") != nil ? ud.bool(forKey: "cam.grid") : false
        if let raw = ud.string(forKey: "cam.filmPreset"),
           let preset = FilmPreset(rawValue: raw) {
            filmPreset = preset
        } else {
            filmPreset = .normal
        }
    }

    // Called from SwiftUI buttons — always on main thread
    func cycleFlash()  { flash = flash.next; ud.set(flash.rawValue, forKey: "cam.flash"); haptic(.light) }
    func cycleDelay()  { delay = delay.next; ud.set(delay.rawValue, forKey: "cam.delay"); haptic(.light) }
    func toggleGrid()  { grid.toggle(); ud.set(grid, forKey: "cam.grid"); haptic(.light) }
    func selectFilmPreset(_ preset: FilmPreset) {
        filmPreset = preset
        ud.set(preset.rawValue, forKey: "cam.filmPreset")
        haptic(.light)
    }
    func shoot()       { haptic(.heavy); onShoot?() }
    func flip()        { haptic(.medium); onFlip?() }
    func zoomPreset(_ f: CGFloat) { haptic(.light); onSetZoom?(f) }
    func adjustExp(_ v: Float)    { onSetExp?(v) }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
