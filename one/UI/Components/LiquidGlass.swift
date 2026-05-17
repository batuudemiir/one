//
//  LiquidGlass.swift
//  one
//
//  iOS 26 Liquid Glass Design System Implementation
//  Based on Apple's official Liquid Glass patterns
//  - Dynamic glass material with blur, reflection, and interactive morphing
//  - SwiftUI native API on iOS 26+, ultraThinMaterial fallback on iOS 17-25
//
//  Updated 2026-05-03: Removed polyfill types (Glass, GlassEffectContainer) that
//  conflicted with real iOS 26 SDK. Now uses native SwiftUI.glassEffect() directly
//  on iOS 26+ and provides .liquidGlass() convenience wrapper for cross-version code.
//

import SwiftUI

// MARK: - Glass Effect Modifier

extension View {
    /// Liquid Glass effect with iOS 26+ native API and fallback
    /// - Parameters:
    ///   - glass: Glass variant (.regular, .clear, .identity) with optional tint and interactivity
    ///   - shape: The shape to apply glass effect to
    func liquidGlass<S: Shape>(
        _ glass: LiquidGlassVariant = .regular,
        in shape: S
    ) -> some View {
        Group {
            if #available(iOS 26, *) {
                self.glassEffect(glass.toNativeGlass(), in: shape)
            } else {
                self.modifier(LiquidGlassFallbackModifier(variant: glass, shape: _ONEAnyShape(shape)))
            }
        }
    }

    func liquidGlassBackground<S: Shape>(
        _ glass: LiquidGlassVariant = .regular,
        in shape: S
    ) -> some View {
        self.background {
            if #available(iOS 26, *) {
                shape.fill(.clear).glassEffect(glass.toNativeGlass(), in: shape)
            } else {
                shape.fill(.ultraThinMaterial)
            }
        }
    }

    func liquidGlassSheetBackground() -> some View {
        Group {
            if #available(iOS 26, *) {
                self.presentationBackground(.clear)
            } else {
                self.presentationBackground(.ultraThinMaterial)
            }
        }
    }

    func liquidGlassToolbar() -> some View {
        Group {
            if #available(iOS 26, *) {
                self
            } else {
                self
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
        }
    }
    
    /// Default shape variant (Capsule)
    func liquidGlass(
        _ glass: LiquidGlassVariant = .regular
    ) -> some View {
        self.liquidGlass(glass, in: Capsule())
    }
    
    /// Convenience method for simple glass effect (backward compatibility)
    func liquidGlass<S: Shape>(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: S
    ) -> some View {
        var variant = LiquidGlassVariant.regular
        if let tintColor = tint {
            variant = variant.tint(tintColor)
        }
        if interactive {
            variant = variant.interactive()
        }
        return self.liquidGlass(variant, in: shape)
    }
    
    /// Backward compatibility with default parameters
    func liquidGlass(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        self.liquidGlass(tint: tint, interactive: interactive, in: Capsule())
    }
}

// MARK: - Glass Variant

/// Liquid Glass variant with tint and interactivity options
struct LiquidGlassVariant: Sendable {
    enum Style: Sendable {
        case regular
        case clear
        case identity
    }
    
    let style: Style
    let tintColor: Color?
    let isInteractive: Bool
    
    static let regular = LiquidGlassVariant(style: .regular, tintColor: nil, isInteractive: false)
    static let clear = LiquidGlassVariant(style: .clear, tintColor: nil, isInteractive: false)
    static let identity = LiquidGlassVariant(style: .identity, tintColor: nil, isInteractive: false)
    
    func tint(_ color: Color) -> LiquidGlassVariant {
        LiquidGlassVariant(style: style, tintColor: color, isInteractive: isInteractive)
    }
    
    func interactive() -> LiquidGlassVariant {
        LiquidGlassVariant(style: style, tintColor: tintColor, isInteractive: true)
    }
    
    @available(iOS 26, *)
    func toNativeGlass() -> SwiftUICore.Glass {
        var glass: SwiftUICore.Glass
        switch style {
        case .regular: glass = .regular
        case .clear: glass = .clear
        case .identity: glass = .identity
        }
        
        if let color = tintColor {
            glass = glass.tint(color)
        }
        
        if isInteractive {
            glass = glass.interactive()
        }
        
        return glass
    }
}

// MARK: - Glass Effect Container (Cross-version wrapper)

/// Container for multiple glass views - enables morphing and performance optimization
struct LiquidGlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 40.0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            // Fallback: simple container without morphing
            content
        }
    }
}

// MARK: - Glass Button Styles

@available(iOS 26, *)
extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle {
        GlassButtonStyle(isProminent: false)
    }
    
    static var glassProminent: GlassButtonStyle {
        GlassButtonStyle(isProminent: true)
    }
}

@available(iOS 26, *)
struct GlassButtonStyle: ButtonStyle {
    let isProminent: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(
                isProminent 
                    ? SwiftUICore.Glass.regular.tint(.accentColor).interactive()
                    : SwiftUICore.Glass.regular.interactive(),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Fallback Implementation (iOS 17-25)

private struct LiquidGlassFallbackModifier: ViewModifier {
    let variant: LiquidGlassVariant
    let shape: _ONEAnyShape
    
    func body(content: Content) -> some View {
        content
            .background(backgroundMaterial)
            .overlay(borderGradient)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var backgroundMaterial: some View {
        Group {
            switch variant.style {
            case .regular:
                if let tintColor = variant.tintColor {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(tintColor.opacity(0.15))
                    }
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            case .clear:
                shape.fill(.thinMaterial)
            case .identity:
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private var borderGradient: some View {
        if variant.style != .identity {
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
    }
}

// MARK: - Shape Type Erasure

private struct _ONEAnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}
