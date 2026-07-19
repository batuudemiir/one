//
//  SavedCollectionsView.swift
//  one
//
//  View to display saved events and songs (Agenda / Listen Later).
//

import SwiftUI

struct SavedCollectionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var savedManager = SavedItemManager.shared
    
    @State private var selectedTab: Int = 0 // 0: Etkinlikler, 1: Müzikler
    
    var body: some View {
        ZStack {
            ONETokens.oneCream.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ONETokens.oneInk)
                    }
                    Spacer()
                    Text("Koleksiyonlar")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ONETokens.oneInk)
                    Spacer()
                    // Balance space
                    Image(systemName: "chevron.left")
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                // Segmented Control
                HStack(spacing: 20) {
                    TabButton(title: "Ajandam", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "Sonra Dinle", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                // Content
                TabView(selection: $selectedTab) {
                    eventsList
                        .tag(0)
                    
                    songsList
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationBarHidden(true)
    }
    
    private var eventsList: some View {
        ScrollView(showsIndicators: false) {
            if savedManager.savedEvents.isEmpty {
                emptyState(title: "Ajandan boş", subtitle: "Keşfet sayfasından etkinlikleri kaydederek buraya ekleyebilirsin.")
            } else {
                VStack(spacing: 16) {
                    ForEach(savedManager.savedEvents) { event in
                        // Wrap with swipe to delete if needed, or context menu to remove
                        DiscoverEventCard(event: event, moodColor: Color(hex: "#4BBFA8"))
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        savedManager.removeEvent(event.id)
                                    }
                                } label: {
                                    Label("Kaldır", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(24)
            }
        }
    }
    
    private var songsList: some View {
        ScrollView(showsIndicators: false) {
            if savedManager.savedSongs.isEmpty {
                emptyState(title: "Liste boş", subtitle: "Keşfet sayfasından beğendiğin şarkıları kaydederek buraya ekleyebilirsin.")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(savedManager.savedSongs) { song in
                        RecommendationCardView(
                            recommendation: song,
                            onTap: {
                                if let urlString = song.spotifyURL, let url = URL(string: urlString) {
                                    UIApplication.shared.open(url)
                                }
                            },
                            onDismiss: {
                                withAnimation {
                                    savedManager.removeSong(song.id)
                                }
                            }
                        )
                    }
                }
                .padding(24)
            }
        }
    }
    
    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 100)
            Image(systemName: "bookmark.slash")
                .font(.system(size: 40))
                .foregroundColor(ONETokens.oneInk.opacity(0.2))
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ONETokens.oneInk)
            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(ONETokens.oneInk.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

fileprivate struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundColor(ONETokens.oneInk.opacity(isSelected ? 1.0 : 0.4))
                
                Rectangle()
                    .fill(isSelected ? ONETokens.oneInk : Color.clear)
                    .frame(height: 2)
            }
            .fixedSize()
        }
    }
}
