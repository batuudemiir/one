//
//  LiquidGlassDemo.swift
//  one
//
//  Demo view showcasing iOS 26 Liquid Glass Design System features
//  - Basic glass effects
//  - Glass containers with morphing
//  - Glass button styles
//  - Interactive glass elements
//

import SwiftUI

#if DEBUG
struct LiquidGlassDemo: View {
    @State private var isExpanded = false
    @Namespace private var namespace
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Liquid Glass")
                        .font(V3Typography.sans(34, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("iOS 26 Design System")
                        .font(V3Typography.sans(14, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(1.2)
                }
                .padding(.top, 40)
                
                // Section 1: Basic Glass Effects
                demoSection(title: "Basic Glass Effects") {
                    VStack(spacing: 16) {
                        // Regular glass
                        Text("Regular Glass")
                            .font(.headline)
                            .padding()
                            .liquidGlass(.regular, in: Capsule())
                        
                        // Clear glass
                        Text("Clear Glass")
                            .font(.headline)
                            .padding()
                            .liquidGlass(.clear, in: RoundedRectangle(cornerRadius: 12))
                        
                        // Tinted glass
                        Text("Tinted Glass")
                            .font(.headline)
                            .padding()
                            .liquidGlass(.regular.tint(.blue), in: Capsule())
                    }
                }
                
                // Section 2: Interactive Glass
                demoSection(title: "Interactive Glass") {
                    HStack(spacing: 16) {
                        ForEach(["heart.fill", "star.fill", "bookmark.fill"], id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(.primary)
                                .frame(width: 60, height: 60)
                                .liquidGlass(.regular.interactive(), in: Circle())
                        }
                    }
                }
                
                // Section 3: Glass Container with Morphing
                demoSection(title: "Glass Container & Morphing") {
                    VStack(spacing: 20) {
                        if #available(iOS 26, *) {
                            LiquidGlassContainer(spacing: 40) {
                                HStack(spacing: 40) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 28))
                                        .frame(width: 70, height: 70)
                                        .liquidGlass()
                                        .glassEffectID("pencil", in: namespace)
                                    
                                    if isExpanded {
                                        Image(systemName: "eraser.fill")
                                            .font(.system(size: 28))
                                            .frame(width: 70, height: 70)
                                            .liquidGlass()
                                            .glassEffectID("eraser", in: namespace)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                        } else {
                            // iOS 17-25: Simple transition without morphing
                            HStack(spacing: 40) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 28))
                                    .frame(width: 70, height: 70)
                                    .liquidGlass()
                                
                                if isExpanded {
                                    Image(systemName: "eraser.fill")
                                        .font(.system(size: 28))
                                        .frame(width: 70, height: 70)
                                        .liquidGlass()
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Text(isExpanded ? "Collapse" : "Expand")
                                .font(V3Typography.sans(14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color.accentColor))
                        }
                    }
                }
                
                // Section 4: Different Shapes
                demoSection(title: "Different Shapes") {
                    HStack(spacing: 16) {
                        // Circle
                        Text("●")
                            .font(V3Typography.sans(32))
                            .frame(width: 70, height: 70)
                            .liquidGlass(.regular, in: Circle())
                        
                        // Rounded Rectangle
                        Text("▢")
                            .font(V3Typography.sans(32))
                            .frame(width: 70, height: 70)
                            .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 16))
                        
                        // Capsule
                        Text("◯")
                            .font(V3Typography.sans(32))
                            .frame(width: 90, height: 70)
                            .liquidGlass(.regular, in: Capsule())
                    }
                }
                
                // Section 6: Tinted Variants
                demoSection(title: "Tinted Variants") {
                    HStack(spacing: 12) {
                        ForEach([Color.red, .orange, .green, .blue, .purple], id: \.self) { color in
                            Circle()
                                .fill(color.opacity(0.2))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(color, lineWidth: 2)
                                )
                                .liquidGlass(.regular.tint(color), in: Circle())
                        }
                    }
                }
                
                // Footer
                Text("Swipe to see effects in different contexts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .background(
            colorScheme == .dark 
                ? Color.black.ignoresSafeArea()
                : Color(white: 0.95).ignoresSafeArea()
        )
    }
    
    @ViewBuilder
    private func demoSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(V3Typography.sans(18, weight: .semibold))
                .foregroundColor(.primary)
            
            content()
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(white: 0.1) : .white)
        )
    }
}

#Preview("Liquid Glass Demo - Light") {
    LiquidGlassDemo()
        .preferredColorScheme(.light)
}

#Preview("Liquid Glass Demo - Dark") {
    LiquidGlassDemo()
        .preferredColorScheme(.dark)
}
#endif
