//
//  DayCell.swift
//  One - Günlük Mood
//

import SwiftUI

// MARK: - Filled Day Cell
struct FilledDayCell: View {
    let entry: DailyEntry
    let isToday: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size.width // Kare olacak, width = height
            
            ZStack(alignment: .topLeading) {
                if let photoURL = entry.photoURL {
                    // Photo background when available - scaledToFill for fixed size
                    AsyncImage(url: photoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: size, height: size)
                                .clipped()
                        default:
                            MoodPatternBackground(moodColorHex: entry.moodColorHex)
                                .frame(width: size, height: size)
                        }
                    }
                    .frame(width: size, height: size)
                } else {
                    // No photo → mood-color pattern
                    MoodPatternBackground(moodColorHex: entry.moodColorHex)
                        .frame(width: size, height: size)
                }
                
                // Gün numarası - kutunun içinde sol üstte
                Text("\(Calendar.current.component(.day, from: entry.date))")
                    .font(.custom("GeistMono-Regular", size: 9))
                    .foregroundColor(Color.white.opacity(0.9))
                    .padding(4)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                Group {
                    if entry.photoURL != nil {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(hex: entry.moodColorHex), lineWidth: 1.5)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(ONETokens.oneShadow, lineWidth: 1.5)
                    }
                }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Empty Day Cell
struct EmptyDayCell: View {
    let dayNumber: Int?
    
    var body: some View {
        // Empty cell with day number inside
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.oneSilver.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            ONETokens.onePebble.opacity(0.7),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                )
            
            // Gün numarası - kutunun içinde sol üstte
            if let day = dayNumber {
                Text("\(day)")
                    .font(.custom("GeistMono-Regular", size: 9))
                    .foregroundColor(ONETokens.oneMist.opacity(0.5))
                    .padding(4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
