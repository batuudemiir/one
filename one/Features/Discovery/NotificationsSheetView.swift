//
//  NotificationsSheetView.swift
//  one
//
//  Placeholder for Notifications
//

import SwiftUI

struct NotificationsSheetView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            ONEBrand.bone.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Bildirimler")
                        .font(V3Typography.sans(18, weight: .bold))
                        .foregroundColor(V3Tokens.ink)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .overlay(
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(V3Tokens.ink)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                )
                
                // Content
                VStack(spacing: 12) {
                    Spacer().frame(height: 100)
                    Image(systemName: "bell.slash")
                        .font(.system(size: 40))
                        .foregroundColor(V3Tokens.ink.opacity(0.2))
                    Text("Yeni Bildirim Yok")
                        .font(V3Typography.sans(18, weight: .bold))
                        .foregroundColor(V3Tokens.ink)
                    Text("Şu an için gösterilecek bir bildirim bulunmuyor.")
                        .font(V3Typography.sans(14, weight: .regular))
                        .foregroundColor(V3Tokens.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            }
        }
    }
}
