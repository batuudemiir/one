//
//  ProfileView.swift
//  one
//
//  User profile setup and management
//  Refactored to use ProfileViewModel, ProfileDashboardView, and ProfileFormView
//

import SwiftUI
import MusicKit

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var vm = ProfileViewModel()
    
    var body: some View {
        ZStack {
            // Zemin token'dan geliyor. Eskiden `vm.isDarkMode ? .black : ...`
            // diye elle seçiliyordu; `V3Tokens.paper` zaten adaptif.
            V3Tokens.paper.ignoresSafeArea()
            
            // Bu view yalnızca `ContentView`'daki ilk kurulum sheet'i olarak
            // açılıyor — profil *sekmesi* `V3ProfileView`. Burada bir zamanlar
            // `isFromTab` ile ikinci bir dal vardı ama hiçbir çağrı yerinde
            // `true` geçilmiyordu; onunla birlikte gelen dashboard →
            // `OnePlusPaywallView` zinciri de ölüydü.
            NavigationStack {
                ProfileFormView(vm: vm, onDismiss: { dismiss() })
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .bodyXSMedium()
                                    .foregroundColor(V3Tokens.mutedText)
                                    .frame(width: 32, height: 32)
                                    .background(V3Tokens.surface.opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .frame(minWidth: V3Tokens.minTouchTarget, minHeight: V3Tokens.minTouchTarget)
                            .contentShape(Rectangle())
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .overlay {
            if vm.profilePhotoZoomed, let img = vm.profileImage {
                ZStack {
                    Color.black.opacity(0.82)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(ONEAnimation.screenTransition) {
                                vm.profilePhotoZoomed = false
                            }
                        }

                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width - 48)
                        .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusTile))
                        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 16)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(ONEAnimation.screenTransition, value: vm.profilePhotoZoomed)
        .task {
            vm.appleMusicStatus = MusicAuthorization.currentStatus
        }
        .onAppear {
            vm.loadExistingProfile()
        }
    }
}

#Preview {
    ProfileView()
}
