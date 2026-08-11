//
//  MonthRecapStoryView.swift
//  One - Günlük Mood
//
//  Faz 3: D30 Sadakati - Aylık özet hikayesi (Spotify Wrapped benzeri)
//

import SwiftUI
import Combine

struct MonthRecapStoryView: View {
    let summary: MonthSummary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var currentSlide = 0
    private let totalSlides = 4
    
    // Timer for auto-advancing slides (e.g., 4 seconds per slide)
    @State private var progress: CGFloat = 0.0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let slideDuration: CGFloat = 80.0 // 80 * 0.05 = 4 seconds
    
    @State private var timerCount: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            // Background
            backgroundForCurrentSlide
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: currentSlide)
            
            VStack {
                // Progress Bar (Story Style)
                HStack(spacing: 4) {
                    ForEach(0..<totalSlides, id: \.self) { index in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .overlay(
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: progressWidth(for: index, in: geo.size.width), alignment: .leading)
                                , alignment: .leading)
                                .clipShape(Capsule())
                        }
                        .frame(height: 3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                // Top Right Close Button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
                
                // Slide Content
                TabView(selection: $currentSlide) {
                    slideIntro
                        .tag(0)
                    
                    slideMood
                        .tag(1)
                    
                    slideMusic
                        .tag(2)
                    
                    slideShare
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                // Normal kaydırmayı kapatıyoruz ki kendi dokunma kontrollerimizi kullanalım
                .disabled(true)
                
                Spacer()
            }
            
            // Tap Gestures for Story Navigation
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        previousSlide()
                    }
                    .accessibilityLabel("Önceki hikaye")
                    .accessibilityAddTraits(.isButton)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        nextSlide()
                    }
                    .accessibilityLabel("Sonraki hikaye")
                    .accessibilityAddTraits(.isButton)
            }
            .ignoresSafeArea()
        }
        .onReceive(timer) { _ in
            // WCAG 2.2.2: Reduce Motion veya VoiceOver açıksa otomatik
            // ilerlemeyi tamamen durdur — kullanıcı tap ile ilerler.
            if reduceMotion || voiceOverEnabled { return }
            guard timerCount < slideDuration else {
                nextSlide()
                return
            }
            // Sadece paylaşım ekranındayken timer'ı durdur (kullanıcı paylaşana kadar beklesin)
            if currentSlide != 3 {
                timerCount += 1
                progress = timerCount / slideDuration
            } else {
                progress = 1.0
            }
        }
    }
    
    // MARK: - Slide Navigation
    private func nextSlide() {
        if currentSlide < totalSlides - 1 {
            withAnimation(.easeInOut) {
                currentSlide += 1
                timerCount = 0
                progress = 0
            }
            ONEHaptics.tabSwitch()
        } else if currentSlide == totalSlides - 1 {
            // Son slayttayken ileri dokunulursa kapat
            dismiss()
        }
    }
    
    private func previousSlide() {
        if currentSlide > 0 {
            withAnimation(.easeInOut) {
                currentSlide -= 1
                timerCount = 0
                progress = 0
            }
            ONEHaptics.tabSwitch()
        } else {
            timerCount = 0
            progress = 0
        }
    }
    
    private func progressWidth(for index: Int, in totalWidth: CGFloat) -> CGFloat {
        if index < currentSlide {
            return totalWidth
        } else if index == currentSlide {
            return totalWidth * progress
        } else {
            return 0
        }
    }
    
    // MARK: - Backgrounds
    @ViewBuilder
    private var backgroundForCurrentSlide: some View {
        switch currentSlide {
        case 0:
            Color(hex: "#1A1A24") // Deep night
        case 1:
            if let topColor = summary.moodDistribution.first?.color {
                Color(hex: topColor).opacity(0.85)
            } else {
                Color(hex: "#2C3E50")
            }
        case 2:
            Color(hex: "#E25A40") // Vibrant music color
        case 3:
            Color(hex: "#EFECE8") // V3Tokens.surface
        default:
            Color.black
        }
    }
    
    // MARK: - Slides
    
    private var slideIntro: some View {
        VStack(spacing: 32) {
            Text(summary.monthName.uppercased())
                .displayXL()
                .italic()
                .fontWeight(.ultraLight)
                .foregroundColor(.white)
            
            Text("Bu ay toplam **\(summary.filledDays)** gününü kayıt altına aldın.")
                .font(.custom("GeistMono-Regular", size: 18))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var slideMood: some View {
        VStack(spacing: 32) {
            Text("Aylık Modun")
                .font(.custom("GeistMono-Regular", size: 14))
                .tracking(3)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
            
            if let topColorHex = summary.moodDistribution.first?.color {
                Circle()
                    .fill(Color(hex: topColorHex))
                    .frame(width: 180, height: 180)
                    .shadow(color: Color(hex: topColorHex).opacity(0.6), radius: 40, x: 0, y: 0)
                
                Text("En çok bu renkte hissettin.")
                    .displayMD()
                    .fontWeight(.light)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
            } else {
                Text("Henüz yeterli veri yok.")
                    .foregroundColor(.white)
            }
        }
    }
    
    private var slideMusic: some View {
        VStack(spacing: 32) {
            Text("Ayın Favorisi")
                .font(.custom("GeistMono-Regular", size: 14))
                .tracking(3)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
            
            if let topArtist = summary.topArtist {
                Text(topArtist)
                    .displayXL()
                    .italic()
                    .fontWeight(.light)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    
                if let topSong = summary.topSong {
                    Text(topSong)
                        .font(.custom("GeistMono-Regular", size: 20))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.top, 10)
                }
            } else {
                Text("Müzik kaydı bulunamadı.")
                    .foregroundColor(.white)
            }
        }
    }
    
    private var slideShare: some View {
        VStack(spacing: 24) {
            let colors = summary.orderedDays.map { date -> Color? in
                if let d = date, let entry = summary.primaryEntry(for: d) {
                    return Color(hex: entry.moodColorHex)
                }
                return nil
            }
            
            Text("Hikayeni Paylaş")
                .font(.custom("GeistMono-Regular", size: 16))
                .tracking(2)
                .foregroundColor(V3Tokens.ink)
            
            // Share Card Preview scaled down
            MonthlyPosterShareCard(
                colors: colors,
                monthName: summary.monthName,
                year: "\(summary.year)"
            )
            .scaleEffect(0.28)
            .frame(width: 1080 * 0.28, height: 1920 * 0.28)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
            
            Button {
                ONEHaptics.songSaved()
                shareCard(colors: colors)
            } label: {
                HStack {
                    Image(systemName: "instagram")
                    Text("Hikayende Paylaş")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(V3Tokens.surface)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(V3Tokens.ink)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
            
            // Butona tıklamak için z-index yüksek bir alan yaratmalıyız çünkü hikaye dokunma alanları var
            // Bunu çözmek için Share slide'ına özel bir overlay ekledik. Buton üstte kalsın diye.
        }
    }
    
    private func shareCard(colors: [Color?]) {
        let view = MonthlyPosterShareCard(colors: colors, monthName: summary.monthName, year: "\(summary.year)")
            .frame(width: 1080, height: 1920)
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        
        if let uiImage = renderer.uiImage {
            let activityVC = UIActivityViewController(activityItems: [uiImage], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
}
