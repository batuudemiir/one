//
//  CircleView+Helpers.swift
//  one
//
//  Helpers extracted from CircleView in Faz 3.1 (2026-04-26):
//  - Unseen share tracking (UserDefaults seen-marker keys)
//  - Local streak computation (Core Data)
//  - CloudKit data loading (initializeUser, loadFriendsShares, performLoadFriendsShares)
//  - Pending requests, friend remove/block, async refresh
//  - Settings deep link helper
//
//  Kept as `extension CircleView` so SwiftUI state remains accessible without
//  passing dozens of bindings — this is the lowest-risk decomposition path.
//

import SwiftUI
import CloudKit
import CoreData

extension CircleView {

    // MARK: - Unseen Share Tracking

    func unseenShareKey(for userID: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return "seenShare_\(userID)_\(f.string(from: Date()))"
    }

    func isUnseenShare(_ data: CloudKitManager.FriendCircleData) -> Bool {
        guard let share = data.share,
              !(share["songName"] as? String ?? "").isEmpty,
              let uid = data.user["userID"] as? String else { return false }
        return !UserDefaults.standard.bool(forKey: unseenShareKey(for: uid))
    }

    func computeUnseenCount() {
        unseenShareCount = friendsShares.filter { isUnseenShare($0) }.count
        cloudKitManager.unseenFriendShareCount = unseenShareCount
    }

    // MARK: - Streak (Core Data)

    func computeLocalStreak() {
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        guard let songs = try? context.fetch(fetchRequest) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let filledDates = Set(songs.compactMap { s -> Date? in
            guard let d = s.date else { return nil }
            return calendar.startOfDay(for: d)
        })

        guard filledDates.contains(today) || filledDates.contains(yesterday) else {
            localCurrentStreak = 0
            return
        }

        let anchor = filledDates.contains(today) ? today : yesterday
        var streak = 0
        var checkDay = anchor
        while filledDates.contains(checkDay) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = prev
        }
        localCurrentStreak = streak
    }

    // MARK: - Faz 3 — Haftalık ritim (Core Data)

    /// Frekans başlığındaki 7 nokta için bu haftanın dolu günlerini okur.
    /// Telafi aksiyonu burada yok — Frekans bir işaret yüzeyi, giriş yüzeyi değil.
    func loadWeekRhythm() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.date(
            from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) else { return }
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? today

        let req: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        req.predicate = NSPredicate(format: "date >= %@ AND date < %@", weekStart as NSDate, weekEnd as NSDate)
        let songs = (try? context.fetch(req)) ?? []

        let filled = songs.reduce(into: [Date: String]()) { acc, s in
            guard let d = s.date, let hex = s.moodColorHex else { return }
            acc[cal.startOfDay(for: d)] = hex
        }
        weekRhythm = WeekRhythm.days(filled: filled, today: today, calendar: cal)
    }

    /// Geri dönüş ekranındaki halkalar: kullanıcı yokken renk bırakmış
    /// arkadaşların mood renkleri. Kimlik göstermiyoruz — sayı ve renk yeter.
    var comebackFriendColors: [Color] {
        friendsShares.compactMap { data in
            guard let share = data.share,
                  !(share["songName"] as? String ?? "").isEmpty,
                  let hex = share["moodColorHex"] as? String else { return nil }
            return Color(hex: hex)
        }
    }

    func getTimeString(from date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - CloudKit User Initialization

    func initializeUser() {
        if cloudKitManager.currentUser != nil {
            loadFriendsShares()
            loadPendingCount()
            // Subscription kaydı oneApp.swift'teki .onChange(of: currentUser) tarafından yapılır.
            return
        }

        if cloudKitManager.isFetchingUser {
            ONELogger.debug("Still fetching user, deferring initialization...", category: .circle)
            return
        }

        cloudKitManager.createOrFetchUser(displayName: "ONE User") { result in
            switch result {
            case .success:
                ONELogger.debug("User initialized successfully", category: .circle)
                self.loadFriendsShares()
                self.loadPendingCount()
                // Subscription kaydı oneApp.swift'teki .onChange(of: currentUser) üstlenir;
                // burada tekrar çağırmak race condition yaratırdı.
            case .failure(let error):
                ONELogger.debug("Error initializing user: \(error)", category: .circle)
                DispatchQueue.main.async {
                    // hasLoadedOnce da set edilmeli: aksi halde `isLoading && !hasLoadedOnce`
                    // yarım bir durumda kalır ve skeleton ile boş durum arasında karar verilemez.
                    self.isLoading = false
                    self.hasLoadedOnce = true
                }
            }
        }
    }

    // MARK: - Friends' Shares Loading

    func loadFriendsShares() {
        if cloudKitManager.currentUser == nil {
            ONELogger.warning("loadFriendsShares: currentUser is nil, waiting...", category: .circle)
            Task {
                let loaded = await cloudKitManager.ensureCurrentUser()
                guard loaded else {
                    ONELogger.error("loadFriendsShares: currentUser still nil after wait", category: .circle)
                    // Sessizce dönmek skeleton'ı sonsuza kadar ekranda bırakıyordu — Çevre
                    // açılış ekranı olduğu için bu doğrudan "uygulama açılmıyor" demek.
                    await MainActor.run {
                        self.isLoading = false
                        self.hasLoadedOnce = true
                    }
                    return
                }
                await MainActor.run {
                    performLoadFriendsShares()
                }
            }
            return
        }
        performLoadFriendsShares()
    }

    func performLoadFriendsShares() {
        guard !isFetchingShares else {
            ONELogger.debug("performLoadFriendsShares: zaten uçuşta, atlanıyor", category: .circle)
            return
        }
        isFetchingShares = true

        // ── Serve today's cache instantly if valid ───────────────────────
        if cloudKitManager.isCircleCacheValid, let cached = cloudKitManager.cachedCircleData {
            self.friendsShares = cached
            if !self.bubblesVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(ONEAnimation.cardSpring) { self.bubblesVisible = true }
                }
            }
            // Still refresh in background
        }

        isLoading = self.friendsShares.isEmpty

        // Load user's own share first
        cloudKitManager.fetchUserDailyShare(for: Date()) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let share):
                    self.userShare = share
                    ONELogger.success("Loaded user's own share", category: .circle)
                case .failure(let error):
                    ONELogger.info("User hasn't shared today: \(error)", category: .circle)
                    self.userShare = nil
                    self.receivedReactions = []
                }
            }
        }

        // Load today's friends' shares only — deduped, one entry per friend
        cloudKitManager.fetchFriendsDailyShares(for: Date()) { result in
            DispatchQueue.main.async {
                self.isFetchingShares = false
                self.isLoading = false
                self.hasLoadedOnce = true
                switch result {
                case .success(let shares):
                    self.friendsShares = shares
                    self.computeUnseenCount()
                    self.cloudKitManager.friendsSharedTodayCount = shares.filter { $0.share != nil }.count
                    self.writeFriendSharesToWidget(shares)
                    WidgetDataWriter.writeStreak(self.localCurrentStreak)
                    if !self.bubblesVisible {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(ONEAnimation.cardSpring) {
                                self.bubblesVisible = true
                            }
                        }
                    }
                case .failure(let error):
                    ONELogger.debug("Error loading shares: \(error)", category: .circle)
                }
            }
        }
    }

    // MARK: - Pending Requests

    func loadPendingCount() {
        cloudKitManager.fetchPendingRequestCount { count in
            withAnimation(ONEAnimation.micro) {
                self.pendingRequestCount = count
            }
        }
    }

    // MARK: - Friend Remove / Block (alert actions)

    func confirmRemoveFriend() {
        guard let friend = friendToRemove else { return }
        let friendUserID = friend.user["userID"] as? String ?? friend.user.recordID.recordName

        cloudKitManager.removeFriend(friendUserID: friendUserID) { result in
            switch result {
            case .success:
                withAnimation(ONEAnimation.micro) {
                    friendsShares.removeAll { $0.id == friend.id }
                }
                ErrorHandler.shared.showSuccess("Arkadaşlıktan çıkarıldı")
            case .failure(let error):
                ErrorHandler.shared.handle(error, context: "remove friend")
            }
            friendToRemove = nil
        }
    }

    func confirmBlockUser() {
        guard let friend = friendToBlock else { return }
        let friendUserID = friend.user["userID"] as? String ?? friend.user.recordID.recordName

        cloudKitManager.blockUser(userID: friendUserID) { result in
            switch result {
            case .success:
                withAnimation(ONEAnimation.micro) {
                    friendsShares.removeAll { $0.id == friend.id }
                }
                ErrorHandler.shared.showSuccess("Kullanıcı engellendi")
            case .failure(let error):
                ErrorHandler.shared.handle(error, context: "block user")
            }
            friendToBlock = nil
        }
    }

    // MARK: - Refresh / Settings

    @MainActor
    func refreshData() async {
        computeLocalStreak()
        loadWeekRhythm()
        cloudKitManager.invalidateCircleCache()
        loadFriendsShares()
        loadPendingCount()
        // Give CloudKit calls time to complete
        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Pulse Animation

    /// Paylaşım yapılmamışsa ve reduce motion kapalıysa nabız animasyonunu başlatır.
    /// `onAppear` ve `onChange(of: reduceMotion)` her ikisinden de güvenle çağrılabilir.
    func startPulseIfNeeded() {
        guard !userHasSharedToday, !reduceMotion else { return }
        withAnimation(
            .easeInOut(duration: 2.8)
            .repeatForever(autoreverses: true)
        ) {
            selfPulseOpacity = 0.35
        }
    }

    // MARK: - Widget Data Sync

    /// Convert FriendCircleData to lightweight dicts and write to App Group for CircleWidget.
    func writeFriendSharesToWidget(_ shares: [CloudKitManager.FriendCircleData]) {
        let dicts = shares.compactMap { data -> [String: String]? in
            guard let name = data.user["displayName"] as? String ?? data.user["userID"] as? String else { return nil }
            let share = data.share
            return [
                "name": name,
                "songName": share?["songName"] as? String ?? "",
                "artistName": share?["artistName"] as? String ?? "",
                "moodColorHex": share?["moodColor"] as? String ?? "#5B8DEF",
                "moodWord": share?["moodWord"] as? String ?? ""
            ]
        }
        WidgetDataWriter.writeFriendShares(dicts)
    }
}
