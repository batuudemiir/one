//
//  CircleShareToggle.swift
//  one
//
//  Prominent toggle for sharing today's entry with Circle friends
//

import SwiftUI

struct CircleShareToggle: View {
    @Binding var isOn: Bool
    let hasPhoto: Bool

    var body: some View {
        Button(action: {
            ONEHaptics.toggle()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isOn ? ONETokens.oneBrand : V3Tokens.surface)
                        .frame(width: 42, height: 42)

                    Image(systemName: isOn ? "person.2.fill" : "person.2")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isOn ? .white : V3Tokens.mutedText)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString("circle.shareWithCircle", comment: ""))
                        .bodySMMedium()
                        .foregroundColor(V3Tokens.ink)

                    Text(subtitleText)
                        .monoSM()
                        .foregroundColor(isOn ? ONETokens.oneBrand : V3Tokens.mutedText)
                }

                Spacer()

                // Toggle indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isOn ? ONETokens.oneBrand : V3Tokens.wash)
                        .frame(width: 44, height: 26)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .offset(x: isOn ? 9 : -9)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg)
                    .fill(isOn ? ONEBrand.kor.opacity(0.08) : V3Tokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: ONETokens.radiusCardLg)
                            .stroke(
                                isOn ? ONEBrand.kor.opacity(0.3) : V3Tokens.faintText.opacity(0.2),
                                lineWidth: isOn ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var subtitleText: String {
        if isOn {
            return hasPhoto
                ? NSLocalizedString("circle.shareWithPhotoDesc", comment: "")
                : NSLocalizedString("circle.shareWithMoodDesc", comment: "")
        } else {
            return NSLocalizedString("circle.shareHint", comment: "")
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
        .background(ONEBrand.bone)
    }
}
