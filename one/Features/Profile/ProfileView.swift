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
    
    var isFromTab: Bool = false
    
    var body: some View {
        ZStack {
            if vm.isDarkMode {
                Color.black.ignoresSafeArea()
            } else {
                ONETokens.oneCream.ignoresSafeArea()
            }
            
            if isFromTab && vm.hasExistingProfile && !vm.isEditingFromTab {
                ProfileDashboardView(vm: vm, isFromTab: isFromTab, context: viewContext)
            } else {
                // Form is presented in a sheet-like manner when coming from tab
                if isFromTab {
                    ProfileFormView(vm: vm, isFromTab: isFromTab, onDismiss: { dismiss() })
                } else {
                    NavigationStack {
                        ProfileFormView(vm: vm, isFromTab: isFromTab, onDismiss: { dismiss() })
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(action: { dismiss() }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(ONETokens.oneAsh)
                                            .frame(width: 32, height: 32)
                                            .background(ONETokens.onePaper.opacity(0.8))
                                            .clipShape(Circle())
                                    }
                                    .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                                    .contentShape(Rectangle())
                                }
                            }
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
        }
        .overlay {
            if vm.profilePhotoZoomed, let img = vm.profileImage {
                ZStack {
                    Color.black.opacity(0.82)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                vm.profilePhotoZoomed = false
                            }
                        }

                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width - 48)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 16)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: vm.profilePhotoZoomed)
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
