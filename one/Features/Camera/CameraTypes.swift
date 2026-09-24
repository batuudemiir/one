//
//  CameraTypes.swift
//  one
//
//  Camera support types: enums, presets, and shared models.
//  Extracted from CameraView.swift as part of Faz 3 decomposition.
//

import SwiftUI
import AVFoundation
import CoreImage
import UIKit

// MARK: - Capture Ratio

enum CaptureRatio: String, CaseIterable {
    case story    = "9:16"
    case standard = "4:3"
    case square   = "1:1"
    var wh: CGFloat {
        switch self {
        case .story:    return 9.0 / 16.0
        case .standard: return 3.0 / 4.0
        case .square:   return 1.0
        }
    }
}

// MARK: - Flash Mode

enum CameraFlash: Int, CaseIterable {
    case off, auto, on
    var next: CameraFlash { CameraFlash(rawValue: (rawValue + 1) % 3) ?? .off }
    var icon: String {
        switch self {
        case .off:  return "bolt.slash.fill"
        case .auto: return "bolt.badge.a.fill"
        case .on:   return "bolt.fill"
        }
    }
    var avMode: AVCaptureDevice.FlashMode {
        switch self { case .off: return .off; case .auto: return .auto; case .on: return .on }
    }
    var isActive: Bool { self != .off }
}

// MARK: - Capture Delay

enum CaptureDelayMode: Int, CaseIterable {
    case off, three, ten
    var next: CaptureDelayMode { CaptureDelayMode(rawValue: (rawValue + 1) % 3) ?? .off }
    var seconds: Int { switch self { case .off: return 0; case .three: return 3; case .ten: return 10 } }
    var badge: String? { switch self { case .off: return nil; case .three: return "3"; case .ten: return "10" } }
    var isActive: Bool { self != .off }
}

// MARK: - Permission State

enum CameraPermState { case checking, authorized, denied }

// MARK: - Film Presets

enum FilmPreset: String, CaseIterable {
    case normal = "Normal"
    case kodak  = "Kodak"
    case fuji   = "Fuji"
    case dispo  = "Dispo"
    case bw     = "B&W"
    case fade   = "Soluk"

    struct Params {
        var saturation:  Float  = 1.0
        var brightness:  Float  = 0.0
        var contrast:    Float  = 1.0
        var temperature: Double = 6500   // Kelvin
        var vignette:    Float  = 0.0
        var grain:       Float  = 0.0    // 0–1
    }

    var params: Params {
        switch self {
        case .normal: return Params()
        case .kodak:  return Params(saturation: 1.08, brightness:  0.04, contrast: 0.94, temperature: 7000, vignette: 0.45, grain: 0.06)
        case .fuji:   return Params(saturation: 0.88, brightness: -0.02, contrast: 1.06, temperature: 6200, vignette: 0.30, grain: 0.04)
        case .dispo:  return Params(saturation: 0.82, brightness:  0.06, contrast: 0.86, temperature: 7400, vignette: 0.72, grain: 0.14)
        case .bw:     return Params(saturation: 0.0,  brightness:  0.00, contrast: 1.10, temperature: 6500, vignette: 0.50, grain: 0.09)
        case .fade:   return Params(saturation: 0.68, brightness:  0.08, contrast: 0.78, temperature: 6800, vignette: 0.22, grain: 0.05)
        }
    }

    // Preview overlay intensities (lighter than photo processing)
    var previewVignette:    Double { Double(params.vignette) * 0.55 }
    var previewGrain:       Double { Double(params.grain) * 1.8   }
    // Live camera modifiers — applied via SwiftUI compositing to the UIKit preview layer
    var previewSaturation:  Double { Double(params.saturation) }
    var previewContrast:    Double { Double(params.contrast) }
    var previewBrightness:  Double { Double(params.brightness) }
}

// MARK: - Film Processing

extension UIImage {
    func applyingFilmPreset(_ preset: FilmPreset) -> UIImage {
        guard preset != .normal,
              let input = CIImage(image: self) else {
            return self
        }

        let params = preset.params
        let context = CIContext(options: nil)
        var output = input

        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(output, forKey: kCIInputImageKey)
            controls.setValue(params.saturation, forKey: kCIInputSaturationKey)
            controls.setValue(params.brightness, forKey: kCIInputBrightnessKey)
            controls.setValue(params.contrast, forKey: kCIInputContrastKey)
            if let image = controls.outputImage {
                output = image
            }
        }

        if let temperature = CIFilter(name: "CITemperatureAndTint") {
            temperature.setValue(output, forKey: kCIInputImageKey)
            temperature.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            temperature.setValue(CIVector(x: params.temperature, y: 0), forKey: "inputTargetNeutral")
            if let image = temperature.outputImage {
                output = image
            }
        }

        if params.vignette > 0, let vignette = CIFilter(name: "CIVignette") {
            vignette.setValue(output, forKey: kCIInputImageKey)
            vignette.setValue(params.vignette * 1.15, forKey: kCIInputIntensityKey)
            vignette.setValue(1.8, forKey: kCIInputRadiusKey)
            if let image = vignette.outputImage {
                output = image
            }
        }

        guard let cgImage = context.createCGImage(output, from: input.extent) else {
            return self
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
