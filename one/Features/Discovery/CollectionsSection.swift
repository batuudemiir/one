import SwiftUI

struct CollectionsSection: View {
    @ObservedObject var vm: KesfetViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
                .padding(.top, 36)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(vm.orderedCollections()) { collection in
                    collectionCell(collection)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var sectionHead: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HAREKETLER")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.89)
                .foregroundColor(Color(hex: "#1A1A1E").opacity(0.35))
            Text("Mood koleksiyonları")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.44)
                .foregroundColor(Color(hex: "#1A1A1E"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func collectionCell(_ collection: KesfetCollection) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: collection.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.white.opacity(0.12), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 100
            )

            VStack(alignment: .leading) {
                Text("\(collection.count) öneri")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 14)
                    .padding(.leading, 14)
                Spacer()
                Text(collection.name)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(.bottom, 14)
                    .padding(.horizontal, 14)
            }
        }
        .aspectRatio(1.05, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
