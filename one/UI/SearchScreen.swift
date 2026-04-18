//
//  SearchScreen.swift
//  one
//
//  Legacy search screen - used within confirm flow
//

import SwiftUI
import MusicKit
import CoreData

struct SearchScreen: View {
    @ObservedObject var vm: ColorPickerViewModel
    @FocusState private var isFocused: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @State private var resultsVisible = false
    
    var body: some View {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, EEEE"
        formatter.locale = LanguageManager.shared.currentLocale
        
        let todaysSong = vm.getTodaysSong(context: viewContext)
        
        return VStack(alignment: .leading, spacing: 0) {
            Text(formatter.string(from: now).uppercased())
                .monoSM(tracking: 2)
                .foregroundColor(ONETokens.oneAsh)
                .padding(.top, 24)
            
            if let saved = todaysSong {
                // Show saved song
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("search.alreadySelected", comment: ""))
                        .displayLG()
                        .foregroundColor(ONETokens.oneInk)
                        .lineSpacing(4)
                        .tracking(-0.02)
                        .padding(.top, 14)
                    
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: saved.moodColorHex ?? "#EEECEA"))
                            .frame(width: 60, height: 60)
                            .overlay(Text(saved.emoji ?? "🎵").font(.system(size: 28)))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(saved.songName ?? "")
                                .monoBase(tracking: 0)
                                .foregroundColor(ONETokens.oneInk)
                            Text(saved.artistName ?? "")
                                .monoSM(tracking: 0)
                                .foregroundColor(ONETokens.oneAsh)
                            Text(saved.moodWord ?? "")
                                .monoBase()
                                .foregroundColor(ONETokens.oneAsh)
                        }
                    }
                    .padding(.top, 20)
                    
                    Text(NSLocalizedString("search.canPickTomorrow", comment: ""))
                        .displaySM()
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.top, 16)
                }
                
                Spacer()
            } else {
                // Normal search flow
                Text(NSLocalizedString("search.todayQuestion", comment: ""))
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                    .padding(.top, 14)
                    .lineSpacing(4)
                    .tracking(-0.02)
                
                // Platform Selector
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(ONEAnimation.cardSpring) {
                            vm.selectedPlatform = .appleMusic
                            vm.searchResults = []
                            vm.errorMessage = nil
                            resultsVisible = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "applelogo")
                            Text("Apple Music")
                        }
                        .monoBase(tracking: 0)
                        .foregroundColor(vm.selectedPlatform == .appleMusic ? .white : ONETokens.oneInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(vm.selectedPlatform == .appleMusic ? ONETokens.appleMusicRed : Color.clear)
                        .clipShape(Capsule())
                        .animation(ONEAnimation.cardSpring, value: vm.selectedPlatform)
                    }
                    .accessibilityLabel("Apple Music")
                    .accessibilityAddTraits(vm.selectedPlatform == .appleMusic ? .isSelected : [])

                    Button(action: {
                        withAnimation(ONEAnimation.cardSpring) {
                            vm.selectedPlatform = .spotify
                            vm.searchResults = []
                            vm.errorMessage = nil
                            resultsVisible = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: SpotifyManager.shared.isAuthenticated ? "checkmark.circle.fill" : "music.note")
                            Text("Spotify")
                        }
                        .monoBase(tracking: 0)
                        .foregroundColor(vm.selectedPlatform == .spotify ? .white : ONETokens.oneInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(vm.selectedPlatform == .spotify ? ONETokens.spotifyGreen : Color.clear)
                        .clipShape(Capsule())
                        .animation(ONEAnimation.cardSpring, value: vm.selectedPlatform)
                    }
                    .accessibilityLabel("Spotify")
                    .accessibilityAddTraits(vm.selectedPlatform == .spotify ? .isSelected : [])
                }
                .accessibilityLabel(NSLocalizedString("accessibility.search.platformPicker", comment: ""))
                .background(ONETokens.oneCreamLow.opacity(0.5))
                .clipShape(Capsule())
                .padding(.top, 24)
                
                // Connection Buttons
                if vm.selectedPlatform == .spotify && !SpotifyManager.shared.isAuthenticated {
                    Button(action: {
                        vm.authenticateSpotify()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                            Text(NSLocalizedString("search.connectSpotify", comment: ""))
                        }
                        .monoSM(tracking: 0)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ONETokens.spotifyGreen)
                        .cornerRadius(12)
                    }
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else if vm.selectedPlatform == .appleMusic {
                    Button(action: {
                        Task {
                            let status = await MusicAuthorization.request()
                            if status != .authorized {
                                vm.errorMessage = NSLocalizedString("search.appleMusicPermission", comment: "")
                            } else {
                                vm.errorMessage = nil
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                            Text(NSLocalizedString("search.connectAppleMusic", comment: ""))
                        }
                        .monoSM(tracking: 0)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ONETokens.appleMusicRed)
                        .cornerRadius(12)
                    }
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                if let error = vm.errorMessage, !vm.searchQuery.isEmpty {
                    Text("\(vm.selectedPlatform == .appleMusic ? "Apple Music" : "Spotify") Hatası: \(error)")
                        .monoBase()
                        .foregroundColor(ONETokens.appleMusicRed)
                        .padding(.top, 12)
                }
                
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.leading, 12)
                    TextField(NSLocalizedString("search.searchPlaceholder", comment: ""), text: $vm.searchQuery)
                        .monoSM(tracking: 0)
                        .padding(.vertical, 14)
                        .focused($isFocused)
                        .onChange(of: vm.searchQuery) { _, newValue in
                            vm.performSearch(query: newValue)
                        }
                }
                .background(isFocused ? ONETokens.onePaper : ONETokens.oneCreamMid)
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(isFocused ? ONETokens.oneCreamLow : Color.clear, lineWidth: 1.5)
                )
                .cornerRadius(13)
                .padding(.top, 26)
                
                // Results List
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Array(vm.filteredSongs.enumerated()), id: \.element.id) { index, song in
                            Button(action: {
                                vm.selectedSong = song
                                vm.selectedMood = nil
                                vm.currentScreen = .confirm
                                isFocused = false
                            }) {
                                SongRow(song: song)
                                    .listItemEntrance(isVisible: resultsVisible, index: index)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider().background(ONETokens.oneCreamMid)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .onChange(of: vm.filteredSongs.count) { _, newCount in
                    if newCount > 0 {
                        resultsVisible = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            resultsVisible = true
                        }
                    } else {
                        resultsVisible = false
                    }
                }
            }
        }
        .padding(.horizontal, 26)
    }
    
    private func deleteTodaysSong() {
        let today = Calendar.current.startOfDay(for: Date())
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", today as NSDate)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            for song in results {
                viewContext.delete(song)
            }
            try viewContext.save()
            
            // Reload archive data
            vm.loadArchiveData(context: viewContext)
        } catch {
            ONELogger.debug("Error deleting today's song: \(error)", category: .music)
        }
    }
}
