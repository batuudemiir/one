//
//  AppLockView.swift
//  one
//
//  Kilit perdesi — `AppLockManager.isLocked` iken kabuğun üstünü kapatır.
//
//  Tasarım: kağıt zemin, kor kelime işareti, tek eylem. Splash'in dilini
//  taklit ediyor ki kilit "hata ekranı" gibi değil, uygulamanın kapısı gibi
//  okunsun. İçerik hiçbir koşulda arkadan sızmaz — perde opak.
//

import SwiftUI

struct AppLockView: View {
    @ObservedObject private var lock = AppLockManager.shared

    var body: some View {
        ZStack {
            V3Tokens.paper.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("ONE")
                    .font(ONEBrand.display(34))
                    .tracking(-1.2)
                    .foregroundColor(ONEBrand.kor)

                Text("Kilitli")
                    .font(V3Typography.mono(11, weight: .regular))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundColor(V3Tokens.ghostText)

                if let error = lock.lastError {
                    Text(error)
                        .bodySM()
                        .foregroundColor(V3Tokens.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, V3Tokens.spacingXL4)
                        .padding(.top, 2)
                }

                Button {
                    lock.authenticate()
                } label: {
                    Text(unlockTitle)
                        .bodyLGSemibold()
                        .foregroundColor(V3Tokens.paper)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(V3Tokens.ink))
                }
                .buttonStyle(.onePressable)
                .disabled(lock.isAuthenticating)
                .opacity(lock.isAuthenticating ? 0.5 : 1)
                .padding(.top, V3Tokens.spacingSM)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ONE kilitli")
    }

    private var unlockTitle: String {
        if let biometry = AppLockManager.biometryLabel() {
            return "\(biometry) ile aç"
        }
        return "Kilidi aç"
    }
}

#Preview {
    AppLockView()
}
