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
    
    
    var body: some View {
        ZStack {
            // BeReal style deep black background
            Color.black
            
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
            
            Text("ADD ME ON")
                .bodyLG()
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, -8)

            Text("ONE")
                .displayXXL()
                .fontWeight(.black)
                .foregroundColor(.white)
                .tracking(4)
                .padding(.bottom, 40)
            
            // Abstract visual profile placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "#121212"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(hex: "#222222"), lineWidth: 1)
                    )
                    .frame(width: 220, height: 260)
                
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color(hex: "#222222"))
                        .frame(width: 90, height: 90)
                        .overlay(
                            Text(String(userName.prefix(1)).uppercased())
                                .displayMD()
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )

                    Text(userName)
                        .displaySM()
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 50)

            VStack(spacing: 8) {
                Text(NSLocalizedString("invite.codeLabel", comment: "").uppercased())
                    .monoSM()
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(2)

                Text(inviteCode.uppercased())
                    .displayMD()
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .tracking(6)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "#121212"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "#222222"), lineWidth: 1)
                            )
                    )
            }
            
            Spacer()
            
            Text("one.forvibe.app")
                .monoSM()
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 30)
        }
    }
    
    private var postLayout: some View {
        HStack(spacing: 0) {
            // Left area: App branding
            VStack(spacing: 0) {
                Spacer()
                Text("ADD ME ON")
                    .bodySM()
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, -6)
                Text("ONE")
                    .displayLG()
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .tracking(4)
                Spacer()
            }
            .frame(width: 260)
            
            // Right area: Profile & Code
            VStack(spacing: 0) {
                Spacer()
                
                HStack(spacing: 20) {
                    Circle()
                        .fill(Color(hex: "#222222"))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Text(String(userName.prefix(1)).uppercased())
                                .displayMD()
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(userName)
                            .displaySM()
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("one.forvibe.app")
                            .monoSM()
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.bottom, 30)

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("invite.codeLabel", comment: "").uppercased())
                        .monoMicro()
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2)

                    Text(inviteCode.uppercased())
                        .displayMD()
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .tracking(4)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "#121212"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#222222"), lineWidth: 1)
                                )
                        )
                }
                
                Spacer()
            }
            .padding(.trailing, 40)
            
            Spacer()
        }
    }
}
