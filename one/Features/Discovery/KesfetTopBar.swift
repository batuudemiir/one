import SwiftUI

struct KesfetTopBar: View {
    @ObservedObject var vm: KesfetViewModel
    @AppStorage(ONETokens.cityPreferenceKey) private var preferredCity: String = ONETokens.defaultCity
    @State private var showSaved = false

    var body: some View {
        HStack(alignment: .center) {
            Text("keşfet")
                .font(V3Typography.sans(22, weight: .bold))
                .foregroundColor(V3Tokens.ink)
            Spacer()
            HStack(spacing: 10) {
                cityPill
                bookmarkButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var cityPill: some View {
        Menu {
            ForEach(ONETokens.availableCities, id: \.self) { city in
                Button(action: { preferredCity = city }) {
                    HStack {
                        Text(city)
                        if city == preferredCity {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(preferredCity)
                    .font(V3Typography.sans(13, weight: .semibold))
            }
            .foregroundColor(V3Tokens.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(V3Tokens.ink.opacity(0.07))
            )
        }
    }


    
    private var bookmarkButton: some View {
        Button(action: { showSaved = true }) {
            Image(systemName: "bookmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(V3Tokens.ink.opacity(0.4))
        }
        .fullScreenCover(isPresented: $showSaved) {
            SavedCollectionsView()
        }
    }
}
