//
//  AppleSignInGateView.swift
//  one
//
//  Zorunlu Apple ile giriş kapısı. Onboarding'ten ve ana uygulamadan
//  ÖNCE gösterilir; kullanıcı giriş yapana kadar başka hiçbir ekran
//  mount edilmez. Görsel dil: onboarding'in "brand" sayfasıyla aynı
//  editoryal minimal ton — beyaz zemin, oneInk metin, alt bantta
//  Apple butonu.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInGateView: View {

    @StateObject private var service = AppleSignInService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            ONEBrand.bone.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 0) {
                    Text("one")
                        .monoLabel(tracking: 1.3)
                        .foregroundColor(V3Tokens.faintText)

                    Text(NSLocalizedString(
                        "signin.title",
                        value: "Hoş geldin.",
                        comment: "Apple sign-in gate title"
                    ))
                    .displayLG()
                    .foregroundColor(V3Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                    Text(NSLocalizedString(
                        "signin.subtitle",
                        value: "Devam etmek için Apple hesabınla giriş yap.",
                        comment: "Apple sign-in gate body"
                    ))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, ONETokens.spacingLG)
                }
                .padding(.horizontal, ONETokens.spacingXL)

                Spacer(minLength: 0)

                SignInWithAppleButton(
                    .continue,
                    onRequest: { request in
                        service.prepare(request: request)
                    },
                    onCompletion: { result in
                        service.handle(result: result)
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 52)
                .clipShape(Capsule(style: .continuous))
                .padding(.horizontal, ONETokens.spacingXL)
                .padding(.bottom, ONETokens.spacingXL3)
                .accessibilityLabel(Text(NSLocalizedString(
                    "signin.button.accessibility",
                    value: "Apple ile giriş yap",
                    comment: ""
                )))
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(reduceMotion ? .linear(duration: 0) : .easeIn(duration: 0.5)) {
                contentOpacity = 1
            }
        }
    }
}

#Preview {
    AppleSignInGateView()
}
