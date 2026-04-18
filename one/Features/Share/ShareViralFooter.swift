//
//  ShareViralFooter.swift
//  one
//
//  Reusable subtle viral attribution placed at the bottom of story /
//  monthly poster share cards. Pairs the invite URL with a small QR so
//  viewers can install the app directly from a screenshot.
//

import SwiftUI

struct ShareViralFooter: View {
    let inviteCode: String?
    var tint: Color = .white
    var qrPixelSize: CGFloat = 120

    private var hasCode: Bool { (inviteCode?.isEmpty == false) }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if hasCode, let code = inviteCode,
               let qr = QRCodeGenerator.inviteQR(code: code, size: qrPixelSize) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("one.forvibe.app")
                    .font(ONETypography.monoSM)
                    .tracking(1.2)
                    .foregroundColor(tint.opacity(0.85))
                if hasCode, let code = inviteCode {
                    Text(code.uppercased())
                        .font(ONETypography.monoBase)
                        .tracking(3.0)
                        .foregroundColor(tint)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
