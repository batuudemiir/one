import SwiftUI

struct MoodSwitcherSheet: View {
    @ObservedObject var vm: KesfetViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
                .padding(.top, 12)
                .padding(.bottom, 20)

            header
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            moodGrid
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            footerInfoCard
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#F5F4EE"))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(hex: "#1A1A1E").opacity(0.18))
            .frame(width: 40, height: 5)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HİSSİNİ DEĞİŞTİR")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.89)
                .foregroundColor(Color(hex: "#1A1A1E").opacity(0.35))
            Text("Hangi hisle keşfedelim?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color(hex: "#1A1A1E"))
            Text("Seçtiğin his, önerileri anında değiştirir.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(hex: "#1A1A1E").opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moodGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(KESFET_MOODS) { mood in
                moodCell(mood)
            }
        }
    }

    @ViewBuilder
    private func moodCell(_ mood: KesfetMood) -> some View {
        let isSelected = vm.selectedMoodId == mood.id
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(mood.color)
                    .frame(width: 58, height: 58)
                    .scaleEffect(isSelected ? 1.04 : 1.0)
                    .overlay(
                        isSelected
                        ? Circle().stroke(.white, lineWidth: 2.5).scaleEffect(1.12)
                        : nil
                    )
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(mood.textOnDark ? Color(hex: "#1A1A1E") : .white)
                }
            }
            Text(mood.label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(isSelected ? Color(hex: "#1A1A1E") : Color(hex: "#1A1A1E").opacity(0.55))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            vm.selectedMoodId = mood.id
            dismiss()
        }
    }

    private var footerInfoCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#1A1A1E").opacity(0.35))
            Text("Seçtiğin his günlüğüne eklenmez — sadece keşfet ekranını kişiselleştirir.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(hex: "#1A1A1E").opacity(0.55))
                .lineLimit(3)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1A1A1E").opacity(0.04))
        )
    }
}
