//
//  ONEColorPickerView.swift
//  one
//
//  Main application view — routes between screens
//

import SwiftUI
import CoreData

// MARK: - Main Application View
struct ONEColorPickerView: View {
    @StateObject private var vm = ColorPickerViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    @State private var todayEntryStep: Step = .search
    
    var body: some View {
        ZStack {
            // Background
            ONETokens.oneCream.ignoresSafeArea()
            
            // Shared tinted gradient for confirm/done screens
            if vm.currentScreen == .confirm || vm.currentScreen == .done {
                GeometryReader { geometry in
                    RadialGradient(
                        gradient: Gradient(colors: [
                            (vm.selectedMood?.color ?? vm.selectedSong?.grad.first ?? Color.clear).opacity(0.15),
                            Color.clear
                        ]),
                        center: .init(x: 0.5, y: vm.currentScreen == .confirm ? 0.3 : 0.5),
                        startRadius: 0,
                        endRadius: geometry.size.width * 0.8
                    )
                    .ignoresSafeArea()
                    .animation(ONEAnimation.moodTransition, value: vm.selectedMood?.color)
                }
            }
            
            // Screen Router
            VStack {
                switch vm.currentScreen {
                case .today, .search:
                    // ── Bugün sekmesi: yeni TodayView ──
                    TodayView(context: viewContext, entryStep: $todayEntryStep)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                        .onChange(of: vm.currentScreen) { _, screen in
                            // Başka sekmeye geçince step'i sıfırla
                            if screen != .today { todayEntryStep = .search }
                        }
                case .confirm:
                    ConfirmScreen(vm: vm, viewContext: viewContext)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .done:
                    DoneScreen(vm: vm)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                case .archive:
                    ArchiveContainerView(context: viewContext)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                case .profile:
                    ProfileView(isFromTab: true)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                case .circle:
                    CircleView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                case .echo:
                    // ── Yankı sekmesi: yeni EchoView ──
                    EchoView(context: viewContext)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(ONEAnimation.cardSpring, value: vm.currentScreen)
            
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if vm.currentScreen != .confirm {
                BottomNavigation(currentScreen: $vm.currentScreen)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            vm.loadArchiveData(context: viewContext)
            vm.loadPatternData(context: viewContext)
        }
        .gesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }

                    let tabs: [ScreenType] = [.echo, .archive, .today, .circle, .profile]
                    guard let currentIndex = tabs.firstIndex(of: vm.currentScreen) else { return }

                    let translation = value.translation.width
                    let threshold: CGFloat = 50

                    if translation < -threshold {
                        if currentIndex < tabs.count - 1 {
                            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = tabs[currentIndex + 1] }
                        }
                    } else if translation > threshold {
                        if currentIndex > 0 {
                            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = tabs[currentIndex - 1] }
                        } else if vm.currentScreen == .archive {
                            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .today }
                        }
                    }
                }
        )
        .onChange(of: notificationManager.shouldNavigateToCircle) { _, shouldNavigate in
            if shouldNavigate {
                withAnimation(ONEAnimation.cardSpring) {
                    vm.currentScreen = .circle
                }
                notificationManager.shouldNavigateToCircle = false
            }
        }
    }
}

// MARK: - Song Row Component
struct SongRow: View {
    let song: Song
    var body: some View {
        HStack(spacing: 12) {
            if let artworkURL = song.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 10).fill(ONETokens.oneCreamMid)
                    }
                }
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(gradient: Gradient(colors: [song.grad[0].opacity(0.6), song.grad[1].opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .overlay(Text(song.emoji).font(.system(size: 20)))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .monoSM(tracking: 0)
                    .foregroundColor(.black)
                    .lineLimit(1)
                Text(song.artist)
                    .monoSM(tracking: 0)
                    .foregroundColor(ONETokens.oneMist)
            }
            Spacer()
            
            Text(song.genre.uppercased())
                .monoLabel()
                .foregroundColor(ONETokens.oneStone)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ONETokens.oneCreamMid)
                .cornerRadius(100)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Mood Button Component
struct MoodButton: View {
    let mood: ONEMood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(mood.color)
                    .frame(width: isSelected ? 56 : 48, height: isSelected ? 56 : 48)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Color.black.opacity(0.2) : Color.clear, lineWidth: 3)
                            .padding(-4)
                    )
                    .shadow(color: isSelected ? mood.color.opacity(0.4) : Color.clear, radius: 10, y: 5)
                    .animation(ONEAnimation.micro, value: isSelected)
                
                Text(mood.label.uppercased())
                    .monoSM(tracking: 1.2)
                    .foregroundColor(isSelected ? .black : ONETokens.oneAsh)
                    .opacity(isSelected ? 1.0 : 0.6)
                    .animation(ONEAnimation.micro, value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Feeling Button Component
struct FeelingButton: View {
    let feeling: FeelingOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon
                FeelingIconView(type: feeling.type)
                    .frame(width: isSelected ? 44 : 40, height: isSelected ? 36 : 32)
                    .opacity(isSelected ? 1.0 : 0.6)
                    .animation(ONEAnimation.micro, value: isSelected)
                
                // Label
                Text(feeling.label.uppercased())
                    .monoLabel(tracking: 0.8)
                    .foregroundColor(isSelected ? ONETokens.oneInk : ONETokens.oneAsh)
                    .opacity(isSelected ? 1.0 : 0.7)
                    .animation(ONEAnimation.micro, value: isSelected)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? ONETokens.oneCreamMid : Color.clear)
                    .animation(ONEAnimation.micro, value: isSelected)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Legacy Pattern Screen (kept for backward compatibility)
struct PatternScreen: View {
    @ObservedObject var vm: ColorPickerViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var animateBars = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YANKILANANLAR")
                .monoBase(tracking: 2)
                .foregroundColor(ONETokens.oneAsh)
                .padding(.top, 24)
            
            Text("Tekrar tekrar\nseçtiklerin.")
                .displayLG()
                .foregroundColor(ONETokens.oneInk)
                .tracking(-0.02)
                .padding(.top, 14)
                .lineSpacing(4)
            
            if vm.songPatterns.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Text("🎵")
                        .font(.system(size: 60))
                        .padding(.top, 60)
                    
                    Text("Henüz yankı yok.")
                        .displaySM()
                        .foregroundColor(ONETokens.oneInk)
                    
                    Text("Aynı şarkıyı birden fazla gün seçtiğinde\nburada görünecek.")
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneAsh)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        ForEach(vm.songPatterns) { pattern in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(pattern.songName)
                                        .font(.system(size: 18, weight: .regular, design: .monospaced))
                                        .foregroundColor(ONETokens.oneInk)
                                        .tracking(-0.01)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(pattern.count) kez")
                                        .monoSM(tracking: 0.06)
                                        .foregroundColor(ONETokens.oneAsh)
                                }
                                
                                Text(pattern.artistName)
                                    .monoSM(tracking: 0)
                                    .foregroundColor(ONETokens.oneAsh)
                                    .lineLimit(1)
                                
                                // Bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(ONETokens.oneCreamLow)
                                            .frame(height: 2)
                                        
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(pattern.color)
                                            .frame(width: animateBars ? geo.size.width * CGFloat(pattern.percentage) : 0, height: 2)
                                    }
                                }
                                .frame(height: 2)
                                .padding(.vertical, 8)
                                
                                Text(pattern.dateString)
                                    .monoBase()
                                    .foregroundColor(ONETokens.oneAsh)
                            }
                        }
                        
                        // Insight Card
                        if let topSong = vm.mostFrequentSong {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    if let emoji = topSong.emoji {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                    }
                                    Spacer()
                                }
                                
                                Text("\"\(topSong.songName)\" senin için özel bir anlam taşıyor gibi. \(topSong.count) kez seçtin.")
                                    .displayXS()
                                    .foregroundColor(ONETokens.oneCream)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 28)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ONETokens.oneInk)
                            .cornerRadius(20)
                            .padding(.top, 20)
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 100)
                }
            }
        }
        .padding(.horizontal, 26)
        .onAppear {
            vm.loadPatternData(context: viewContext)
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.2)) {
                animateBars = true
            }
        }
    }
}

// MARK: - Animations
// BreathingAnimation now provided by DesignSystem/ONEAnimation.swift

// MARK: - Preview
struct ONEColorPickerView_Previews: PreviewProvider {
    static var previews: some View {
        ONEColorPickerView()
    }
}
