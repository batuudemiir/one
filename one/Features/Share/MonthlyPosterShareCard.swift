//
//  MonthlyPosterShareCard.swift
//  One - Günlük Mood
//
//  Created by ONE on 2026.
//

import SwiftUI

// MARK: - Monthly Poster Share Card
struct MonthlyPosterShareCard: View {
    let colors: [Color?]
    let monthName: String
    let year: String
    
    // Wabi-Sabi grid of up to 30 colors (or recent 30 days)
    var body: some View {
        ZStack {
            // Arka plan rengi (Wabi-Sabi cream)
            ONETokens.onePaper.ignoresSafeArea()
            
            VStack {
                // MARK: Top Section (Title)
                VStack(alignment: .leading, spacing: 4) {
                    Text(monthName.uppercased())
                        .font(.system(size: 64, design: .serif))
                        .italic()
                        .fontWeight(.ultraLight)
                        .foregroundColor(ONETokens.oneShadow)
                        .tracking(-1.5)
                        
                    Text(year)
                        .font(.custom("GeistMono-Regular", size: 16))
                        .tracking(4.0)
                        .foregroundColor(ONETokens.oneMist)
                }
                .padding(.top, 80)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // MARK: Middle Section (Wave or Grid)
                // Using a 5 columns x 6 rows grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(0..<min(30, colors.count), id: \.self) { index in
                        if let color = colors[index] {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(color)
                                .aspectRatio(1, contentMode: .fit)
                        } else {
                            // Boş gün görünümü
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ONETokens.oneSilver.opacity(0.3))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .padding(.horizontal, 50)
                
                Spacer()
                
                // MARK: Bottom Section (App Branding)
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(ONETokens.oneIvory)
                        .frame(width: 80, height: 1)
                    
                    Text(NSLocalizedString("monthly.echoTagline", comment: ""))
                        .font(.custom("GeistMono-Regular", size: 12))
                        .tracking(1.5)
                        .foregroundColor(ONETokens.oneMist)
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1920) // For Instagram Story size
    }
}
