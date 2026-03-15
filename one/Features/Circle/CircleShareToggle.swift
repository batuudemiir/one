//
//  CircleShareToggle.swift
//  one
//
//  Wabi-Sabi minimalist toggle for Circle photo sharing
//

import SwiftUI

struct CircleShareToggle: View {
    @Binding var isOn: Bool
    let hasPhoto: Bool
    
    var body: some View {
        if hasPhoto {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Toggle switch
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            isOn.toggle()
                        }
                        
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        ZStack {
                            // Background track
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isOn ? ONETokens.oneInk : ONETokens.oneCreamLow)
                                .frame(width: 36, height: 20)
                            
                            // Knob
                            Circle()
                                .fill(Color.white)
                                .frame(width: 14, height: 14)
                                .offset(x: isOn ? 8 : -8)
                        }
                    }
                    
                    // Label
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Çevrenle paylaş")
                            .monoSM(tracking: 0)
                            .foregroundColor(ONETokens.oneInk)
                        
                        if isOn {
                            Text("Gece yarısına kadar")
                                .monoSM()
                                .foregroundColor(ONETokens.oneAsh)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(ONETokens.oneInk.opacity(0.1), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ONETokens.oneCream)
                        )
                )
                
                // Info text
                if isOn {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(ONETokens.oneAsh)
                        
                        Text("Fotoğrafın çevrende görünür olacak")
                            .monoBase()
                            .foregroundColor(ONETokens.oneAsh)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

// MARK: - Preview

struct CircleShareToggle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CircleShareToggle(isOn: .constant(false), hasPhoto: true)
            CircleShareToggle(isOn: .constant(true), hasPhoto: true)
            CircleShareToggle(isOn: .constant(false), hasPhoto: false)
        }
        .padding()
        .background(ONETokens.oneCream)
    }
}
