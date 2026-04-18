//
//  InviteShareCard.swift
//  one
//
//  Visual invite card for sharing via Instagram Stories and other platforms.
//  Rendered at 360x640 points with scale 3.0 -> 1080x1920 pixels.
//

import SwiftUI

enum ShareFormat {
    case story
    case post
}

struct InviteShareCard: View {
    let inviteCode: String
    let userName: String
    var format: ShareFormat = .story
    
    // Aesthetic colors for the card
    private let bgColor1 = Color(hex: "#151516")
    private let bgColor2 = Color(hex: "#2C2C2C")
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [bgColor1, bgColor2],
                startPoint: format == .post ? .leading : .topLeading,
                endPoint: format == .post ? .trailing : .bottomTrailing
            )
            
            // Abstract Circles / Noise
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(ONETokens.onePaper.opacity(0.04))
                        .frame(width: 300, height: 300)
                        .offset(x: format == .post ? geometry.size.width * 0.7 : geometry.size.width * 0.5, y: -50)
                        .blur(radius: 20)
                    
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .offset(x: -80, y: format == .post ? geometry.size.height * 0.8 : geometry.size.height * 0.6)
                        .blur(radius: 15)
                }
            }
            .clipped()
            
            if format == .story {
                storyLayout
            } else {
                postLayout
            }
        }
        .frame(width: format == .story ? 360 : 600, height: format == .story ? 640 : 337.5)
    }
    
    // MARK: - Layouts
    
    private var storyLayout: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image("hi")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.bottom, 40)
            
            Text(String(format: NSLocalizedString("invite.invitesYou", comment: ""), userName.uppercased()))
                .monoLabel(tracking: 2.0)
                .foregroundColor(ONETokens.oneAsh)
                .padding(.bottom, 12)

            Text(NSLocalizedString("app.slogan", comment: ""))
                .displayXL()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 60)

            VStack(spacing: 8) {
                Text(NSLocalizedString("invite.codeLabel", comment: ""))
                    .monoSM(tracking: 1.5)
                    .foregroundColor(ONETokens.oneAsh)
                
                Text(inviteCode.uppercased())
                    .monoBase(tracking: 4.0)
                    .foregroundColor(ONETokens.oneInk)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ONETokens.onePaper)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .padding(.bottom, 100)
            
            Text(NSLocalizedString("invite.footer", comment: ""))
                .monoMicro(tracking: 1.0)
                .foregroundColor(.white.opacity(0.4))
                .padding(.bottom, 60)
        }
        .padding(.horizontal, 32)
    }
    
    private var postLayout: some View {
        HStack(spacing: 0) {
            // Left mascot area
            VStack {
                Spacer()
                Image("hi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                Spacer()
            }
            .frame(width: 240)
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                Text(String(format: NSLocalizedString("invite.invitesYou", comment: ""), userName.uppercased()))
                    .monoLabel(tracking: 2.0)
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.bottom, 8)

                Text(NSLocalizedString("app.slogan", comment: ""))
                    .displayXL()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .padding(.bottom, 32)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("invite.codeLabel", comment: ""))
                            .monoSM(tracking: 1.5)
                            .foregroundColor(ONETokens.oneAsh)
                        
                        Text(inviteCode.uppercased())
                            .monoBase(tracking: 4.0)
                            .foregroundColor(ONETokens.oneInk)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ONETokens.onePaper)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    Spacer()
                    Text(NSLocalizedString("invite.footer", comment: ""))
                        .monoMicro(tracking: 1.0)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 4)
                }
                
                Spacer()
            }
            .padding(.vertical, 32)
            .padding(.trailing, 40)
        }
    }
}
