import SwiftUI

struct VenueDetailSheet: View {
    let payload: VenueSheetPayload
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            heroSection
            bodySection
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(hex: "#F5F4EE"))
    }

    private var heroSection: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: payload.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)

            VStack(spacing: 0) {
                HStack {
                    dragHandle
                    Spacer()
                }
                .padding(.top, 14)
                .padding(.horizontal, 20)

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        kindPill
                        Spacer()
                        closeButton
                    }
                    .padding(.horizontal, 20)

                    Text(payload.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    Text(payload.sub)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
            .frame(height: 280)
        }
    }

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.white.opacity(0.4))
            .frame(width: 40, height: 5)
    }

    private var kindPill: some View {
        Text(payload.kindLabel)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.2)))
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.white.opacity(0.2)))
        }
    }

    private var bodySection: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    metaPills
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                    whySection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    lineupSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }

            Divider()
            footerActions
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
    }

    private var metaPills: some View {
        HStack(spacing: 8) {
            if !payload.distance.isEmpty {
                metaPill(icon: "location", text: payload.distance)
            }
            metaPill(icon: "clock", text: payload.time)
            metaPill(icon: "waveform", text: "Canlı")
        }
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(Color(hex: "#1A1A1E").opacity(0.75))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color(hex: "#1A1A1E").opacity(0.07))
        )
    }

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEDEN SANA")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.89)
                .foregroundColor(Color(hex: "#1A1A1E").opacity(0.35))
            Text(payload.why)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(hex: "#1A1A1E").opacity(0.75))
                .lineSpacing(4)
        }
    }

    private var lineupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AKIŞ")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.89)
                .foregroundColor(Color(hex: "#1A1A1E").opacity(0.35))
            ForEach(payload.lineup) { item in
                HStack {
                    Text(item.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#1A1A1E"))
                    Spacer()
                    Text(item.time)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "#1A1A1E").opacity(0.55))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#EFEEE7"))
                )
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 12) {
            Button {
            } label: {
                Text("Kaydet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#1A1A1E"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: "#1A1A1E").opacity(0.07))
                    )
            }

            Button {
            } label: {
                Text("Bilet Al")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: "#1A1A1E"))
                    )
            }
        }
    }
}
