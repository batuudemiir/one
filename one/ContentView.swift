import SwiftUI

struct ContentView: View {
    @State private var isActive = false
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showProfileSetup = false
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                // First time user - show onboarding
                OnboardingView(isCompleted: $hasCompletedOnboarding)
            } else if isActive {
                // Main app — aşağıdan yukarı gelir, splash'in üzerine oturur
                ONEColorPickerView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                // Splash screen — kapanırken scale küçülür ve solar
                SplashScreen(isActive: $isActive)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 0.94).combined(with: .opacity)
                    ))
            }
        }
        .animation(ONEAnimation.screenTransition, value: isActive)
        .overlay { ONEToastOverlay() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("resetToOnboarding"))) { _ in
            withAnimation(ONEAnimation.screenTransition) {
                isActive = false
                hasCompletedOnboarding = false
            }
        }
        .sheet(isPresented: $showProfileSetup) {
            ProfileView()
                .interactiveDismissDisabled(true) // Prevent dismissing without saving
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if completed {
                ONELogger.debug("Onboarding completed, checking profile status", category: .general)
                checkProfileStatus()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                ONELogger.debug("App became active, checking profile status", category: .general)
                checkProfileStatus()
            }
        }
        .onChange(of: cloudKitManager.isFetchingUser) { _, isFetching in
            if !isFetching && !UserDefaults.standard.bool(forKey: "hasCreatedProfile") {
                if cloudKitManager.currentUser == nil {
                    ONELogger.warning("finished fetching, no user found, showing profile setup", category: .general)
                    showProfileSetup = true
                } else {
                    ONELogger.success("finished fetching, found user, setting flag", category: .general)
                    UserDefaults.standard.set(true, forKey: "hasCreatedProfile")
                }
            }
        }
        .onAppear {
            ONELogger.debug("ContentView appeared", category: .general)
            ONELogger.debug("hasCompletedOnboarding: \(hasCompletedOnboarding)", category: .general)
            ONELogger.debug("hasCreatedProfile: \(UserDefaults.standard.bool(forKey: "hasCreatedProfile"))", category: .general)
            ONELogger.debug("currentUser exists: \(cloudKitManager.currentUser != nil)", category: .general)
            ONELogger.debug("isFetchingUser: \(cloudKitManager.isFetchingUser)", category: .general)
            
            if hasCompletedOnboarding {
                checkProfileStatus()
            }
        }
    }
    
    private func checkProfileStatus() {
        // Check UserDefaults flag first - this is the source of truth
        let hasCreatedProfile = UserDefaults.standard.bool(forKey: "hasCreatedProfile")
        
        ONELogger.debug("Checking profile status:", category: .general)
        ONELogger.debug("hasCreatedProfile flag: \(hasCreatedProfile)", category: .general)
        ONELogger.debug("currentUser exists: \(cloudKitManager.currentUser != nil)", category: .general)
        
        if hasCreatedProfile {
            // Profile already created, no need to show setup
            ONELogger.success("Profile already created (flag is set)", category: .general)
            
            // If flag is set but currentUser is nil, try to load it
            if cloudKitManager.currentUser == nil && !cloudKitManager.isFetchingUser {
                ONELogger.warning("Flag is set but currentUser is nil, loading from CloudKit...", category: .general)
                cloudKitManager.loadCurrentUser()
            }
            return
        }
        
        // No profile flag, check if user exists in CloudKit
        ONELogger.warning("No profile flag, checking CloudKit...", category: .general)
        
        if cloudKitManager.currentUser != nil {
            // User exists in CloudKit but flag not set - fix the flag
            ONELogger.success("Found user in CloudKit, setting flag", category: .general)
            UserDefaults.standard.set(true, forKey: "hasCreatedProfile")
        } else {
            // Wait for CloudKit to finish fetching, then check again
            if cloudKitManager.isFetchingUser {
                ONELogger.debug("CloudKit is currently fetching user, waiting...", category: .general)
                // We will handle the result when isFetchingUser changes via the onChange below
            } else {
                // Not fetching and no user, safe to show profile setup
                ONELogger.warning("No user found, showing profile setup", category: .general)
                self.showProfileSetup = true
            }
        }
    }
}

#Preview {
    ContentView()
}
