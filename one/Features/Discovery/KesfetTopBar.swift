import SwiftUI

struct KesfetTopBar: View {
    @ObservedObject var vm: KesfetViewModel
    @AppStorage(ONETokens.cityPreferenceKey) private var preferredCity: String = ONETokens.defaultCity
    @State private var showSaved = false

    var body: some View {
        HStack(alignment: .center) {
            Text("keşfet")
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(ONETokens.oneInk)
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
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(ONETokens.oneInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(ONETokens.oneInk.opacity(0.07))
            )
        }
    }


    
    private var bookmarkButton: some View {
        Button(action: { showSaved = true }) {
            Image(systemName: "bookmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ONETokens.oneInk.opacity(0.4))
        }
        .fullScreenCover(isPresented: $showSaved) {
            SavedCollectionsView()
        }
    }
}
