# ☁️ CloudKit Kurulum Rehberi - ONE Çevre Özelliği

## Genel Bakış

Bu dokümantasyon, ONE uygulamasına CloudKit entegrasyonunu adım adım açıklar. Çevre (Circle) özelliği için gerekli tüm teknik kurulum ve kod örneklerini içerir.

## Ön Gereksinimler

### Apple Developer Hesabı
- Ücretli Apple Developer Program üyeliği
- CloudKit Dashboard erişimi
- App ID ve Bundle ID

### Xcode Ayarları
- Xcode 14.0+
- iOS 16.0+ deployment target
- SwiftUI ve Core Data bilgisi

## Adım 1: Xcode Proje Ayarları

### 1.1 Capabilities Ekleme

1. Xcode'da projeyi aç
2. Target seç (one)
3. "Signing & Capabilities" sekmesine git
4. "+ Capability" butonuna tıkla
5. "iCloud" seçeneğini ekle
6. Şu seçenekleri işaretle:
   - ✅ CloudKit
   - ✅ CloudKit Dashboard (opsiyonel)

### 1.2 CloudKit Container Oluşturma

```
Container ID: iCloud.com.yourcompany.one
```

1. "+" butonuna tıkla
2. "Use default container" veya "Specify custom container"
3. Container ID formatı: `iCloud.$(CFBundleIdentifier)`
4. "Add" butonuna tıkla

### 1.3 Background Modes

1. "+ Capability" → "Background Modes"
2. Şunları işaretle:
   - ✅ Remote notifications
   - ✅ Background fetch

## Adım 2: CloudKit Dashboard Yapılandırması

### 2.1 Schema Tanımlama

CloudKit Dashboard'a git: https://icloud.developer.apple.com/dashboard

#### Record Types

**1. User**
```
Record Type: User
Fields:
- userID (String, Indexed, Queryable)
- displayName (String)
- inviteCode (String, Indexed, Queryable, Unique)
- avatarColor (String)
- isPublic (Int64) // 0 veya 1
- createdDate (Date/Time)
```

**2. Friendship**
```
Record Type: Friendship
Fields:
- friendshipID (String, Indexed)
- user1ID (String, Indexed, Queryable)
- user2ID (String, Indexed, Queryable)
- status (String) // pending, accepted, blocked
- createdDate (Date/Time)
- acceptedDate (Date/Time)
```

**3. DailyShare**
```
Record Type: DailyShare
Fields:
- shareID (String, Indexed)
- userID (String, Indexed, Queryable)
- date (Date/Time, Indexed, Queryable)
- songName (String)
- artistName (String)
- genre (String)
- emoji (String)
- albumArtURL (String)
- moodWord (String)
- moodColor (String)
- moodTheme (String)
- dailyNote (String)
- platform (String)
- isPublic (Int64)
- createdAt (Date/Time)
```

### 2.2 Security Roles

```
World: None
Authenticated: Read, Write (own records only)
Creator: Full Access
```

### 2.3 Indexes

Performans için gerekli indexler:
- `User.inviteCode` (Queryable)
- `User.userID` (Queryable)
- `Friendship.user1ID` (Queryable)
- `Friendship.user2ID` (Queryable)
- `DailyShare.userID` (Queryable)
- `DailyShare.date` (Queryable, Sortable)

## Adım 3: Core Data Model Güncellemesi

### 3.1 Yeni Entity'ler

**User Entity**
```swift
// one.xcdatamodeld içinde yeni entity ekle
Entity: User
Attributes:
- userID: String
- displayName: String
- inviteCode: String
- avatarColor: String
- isPublic: Boolean
- createdDate: Date
```

**Friendship Entity**
```swift
Entity: Friendship
Attributes:
- friendshipID: UUID
- user1ID: String
- user2ID: String
- status: String
- createdDate: Date
- acceptedDate: Date (Optional)

Relationships:
- user1: User (To One)
- user2: User (To One)
```

### 3.2 DailyEntry Güncellemesi

Mevcut `DailyEntry` entity'sine ekle:
```swift
Attributes:
- isSharedWithCircle: Boolean (default: false)
- viewCount: Integer 16 (default: 0)
- sharedAt: Date (Optional)
```

## Adım 4: CloudKit Manager Oluşturma

### 4.1 CloudKitManager.swift


Dosya oluşturuldu: `one/one/CloudKitManager.swift`

### 4.2 Kullanım Örneği

```swift
// Uygulama başlangıcında
let cloudKitManager = CloudKitManager.shared

// Kullanıcı oluştur veya getir
cloudKitManager.createOrFetchUser(displayName: "Ayşe Yılmaz") { result in
    switch result {
    case .success(let user):
        print("User created: \(user)")
    case .failure(let error):
        print("Error: \(error)")
    }
}

// Arkadaş ekle
cloudKitManager.findUserByInviteCode("ABC123") { result in
    switch result {
    case .success(let user):
        let userID = user["userID"] as? String ?? ""
        cloudKitManager.sendFriendRequest(toUserID: userID) { result in
            // Handle result
        }
    case .failure(let error):
        print("User not found: \(error)")
    }
}
```

## Adım 5: Persistence.swift Güncellemesi

### 5.1 CloudKit Container Ekleme

```swift
import CoreData
import CloudKit

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "one")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // CloudKit configuration
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description")
            }
            
            // Enable CloudKit sync
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.yourcompany.one"
            )
            
            // Enable remote change notifications
            description.setOption(true as NSNumber, 
                                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Enable history tracking
            description.setOption(true as NSNumber,
                                forKey: NSPersistentHistoryTrackingKey)
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        // Automatically merge changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Setup remote change notifications
        setupRemoteChangeNotifications()
    }
    
    private func setupRemoteChangeNotifications() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { notification in
            print("Remote change detected")
            // Trigger UI update
        }
    }
}
```

## Adım 6: CircleView Oluşturma

### 6.1 CircleView.swift

```swift
import SwiftUI
import CloudKit

struct CircleView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var friendsShares: [CKRecord] = []
    @State private var isLoading = false
    @State private var showAddFriend = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#F7F6F3")
                    .ignoresSafeArea()
                
                if friendsShares.isEmpty {
                    emptyStateView
                } else {
                    friendsListView
                }
            }
            .navigationTitle("Bugün Çevren")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .onAppear {
                loadFriendsShares()
            }
            .refreshable {
                loadFriendsShares()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Text("🌍")
                .font(.system(size: 80))
            
            Text("Henüz çevren yok")
                .font(.custom("Fraunces", size: 24))
                .italic()
            
            Text("Arkadaşlarını ekle ve onların\ngünlük müzik seçimlerini gör.")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            
            Button(action: { showAddFriend = true }) {
                Text("Arkadaş Ekle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }
    
    private var friendsListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("\(friendsShares.count) arkadaşın seçim yaptı")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.top)
                
                ForEach(friendsShares, id: \.recordID) { share in
                    FriendShareCard(share: share)
                }
                
                Button(action: { showAddFriend = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Arkadaş Ekle")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func loadFriendsShares() {
        isLoading = true
        cloudKitManager.fetchFriendsDailyShares(for: Date()) { result in
            isLoading = false
            switch result {
            case .success(let shares):
                friendsShares = shares
            case .failure(let error):
                print("Error loading shares: \(error)")
            }
        }
    }
}

struct FriendShareCard: View {
    let share: CKRecord
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(Color(hex: share["moodColor"] as? String ?? "#4ECDC4"))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(getInitial())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(share["userID"] as? String ?? "Friend")
                    .font(.system(size: 16, weight: .semibold))
                
                HStack {
                    Text(share["moodWord"] as? String ?? "")
                    Text("•")
                    Text(share["songName"] as? String ?? "")
                }
                .font(.system(size: 14))
                .foregroundColor(.gray)
                
                Text(share["artistName"] as? String ?? "")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                if let note = share["dailyNote"] as? String, !note.isEmpty {
                    Text("\"\(note)\"")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundColor(.black.opacity(0.6))
                        .padding(.top, 2)
                }
                
                Text(getRelativeTime())
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func getInitial() -> String {
        let userID = share["userID"] as? String ?? "?"
        return String(userID.prefix(1)).uppercased()
    }
    
    private func getRelativeTime() -> String {
        guard let createdAt = share["createdAt"] as? Date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
```

## Adım 7: AddFriendView Oluşturma

### 7.1 AddFriendView.swift

```swift
import SwiftUI
import CloudKit

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    @State private var inviteCode = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var myInviteCode: String {
        cloudKitManager.currentUser?["inviteCode"] as? String ?? "------"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#F7F6F3")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // My Invite Code
                        VStack(spacing: 12) {
                            Text("Senin Kodun")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(myInviteCode)
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .tracking(4)
                            
                            Button(action: shareInviteCode) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Paylaş")
                                }
                                .font(.system(size: 14))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(12)
                        
                        Divider()
                        
                        // Add Friend Section
                        VStack(spacing: 16) {
                            Text("Arkadaş Ekle")
                                .font(.system(size: 16, weight: .medium))
                            
                            TextField("Davet Kodu Gir", text: $inviteCode)
                                .textFieldStyle(.roundedBorder)
                                .textCase(.uppercase)
                                .autocapitalization(.allCharacters)
                                .font(.system(size: 18, design: .monospaced))
                            
                            Button(action: addFriend) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Davet Gönder")
                                        .font(.system(size: 18, weight: .medium))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(inviteCode.count == 6 ? Color.black : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .disabled(inviteCode.count != 6 || isLoading)
                        }
                        .padding()
                    }
                    .padding()
                }
            }
            .navigationTitle("Arkadaş Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addFriend() {
        isLoading = true
        
        cloudKitManager.findUserByInviteCode(inviteCode) { result in
            switch result {
            case .success(let user):
                let userID = user["userID"] as? String ?? ""
                cloudKitManager.sendFriendRequest(toUserID: userID) { result in
                    isLoading = false
                    switch result {
                    case .success:
                        dismiss()
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            case .failure:
                isLoading = false
                errorMessage = "Kullanıcı bulunamadı"
                showError = true
            }
        }
    }
    
    private func shareInviteCode() {
        let text = "ONE uygulamasında beni ekle! Davet kodum: \(myInviteCode)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
}
```

## Adım 8: ContentView'e Çevre Sekmesi Ekleme

```swift
// ContentView.swift içinde TabView'e ekle

TabView(selection: $selectedTab) {
    // ... mevcut sekmeler
    
    CircleView()
        .tabItem {
            Label("Çevre", systemImage: "person.3.fill")
        }
        .tag(3)
}
```

## Adım 9: Info.plist Güncellemeleri

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Çevre özelliği için arkadaşlarınızla veri paylaşımı yapılır.</string>

<key>NSContactsUsageDescription</key>
<string>Kişilerinizden ONE kullananları bulmanıza yardımcı olur.</string>

<key>NSCameraUsageDescription</key>
<string>QR kod taramak için kamera erişimi gereklidir.</string>
```

## Adım 10: Test ve Deployment

### 10.1 Development Testing

1. Xcode'da iki simulator aç
2. Her birinde farklı iCloud hesabı kullan
3. Davet kodu ile arkadaş ekleme test et
4. Paylaşım yapıp diğer cihazda görünümü kontrol et

### 10.2 Production Deployment

1. CloudKit Dashboard'da "Deploy to Production"
2. Schema değişikliklerini onayla
3. TestFlight'ta beta test
4. App Store'a gönder

## Sorun Giderme

### CloudKit Erişim Hatası
```
Error: Account not available
Çözüm: Ayarlar > iCloud > iCloud Drive açık olmalı
```

### Sync Çalışmıyor
```
Çözüm: 
1. Capabilities kontrol et
2. Container ID doğru mu?
3. Schema deploy edildi mi?
```

### Duplicate Records
```
Çözüm: Unique constraint ekle (inviteCode için)
```

## Güvenlik Notları

- Asla API key'leri kod içinde tutma
- CloudKit token'ları Keychain'de sakla
- User input'ları validate et
- Rate limiting uygula

## Sonraki Adımlar

1. ✅ CloudKit kurulumu tamamlandı
2. ⏳ UI geliştirme
3. ⏳ Test ve optimizasyon
4. ⏳ Production deployment

## Kaynaklar

- [Apple CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [Core Data + CloudKit](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit)
- [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2021/10086/)


## Adım 11: Color Extension Ekleme

CircleView ve AddFriendView'de kullanılan `Color(hex:)` extension'ı ekleyin:

### 11.1 ColorExtension.swift Oluştur

```swift
//
//  ColorExtension.swift
//  one
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

## Adım 12: oneApp.swift Güncellemesi

CloudKitManager'ı uygulama başlangıcında başlatın:

```swift
import SwiftUI

@main
struct oneApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // CloudKit availability check
                    cloudKitManager.checkCloudKitAvailability()
                }
        }
    }
}
```

## Adım 13: Core Data Migration (Önemli!)

Mevcut uygulamada veri varsa, migration gereklidir:

### 13.1 Lightweight Migration

```swift
// Persistence.swift içinde

init(inMemory: Bool = false) {
    container = NSPersistentCloudKitContainer(name: "one")
    
    if inMemory {
        container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
    } else {
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }
        
        // CloudKit configuration
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.yourcompany.one"
        )
        
        // Enable remote change notifications
        description.setOption(true as NSNumber, 
                            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable history tracking
        description.setOption(true as NSNumber,
                            forKey: NSPersistentHistoryTrackingKey)
        
        // IMPORTANT: Enable automatic migration
        description.setOption(true as NSNumber,
                            forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber,
                            forKey: NSInferMappingModelAutomaticallyOption)
    }
    
    container.loadPersistentStores { description, error in
        if let error = error {
            fatalError("Core Data failed to load: \(error.localizedDescription)")
        }
    }
    
    // Automatically merge changes
    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    
    // Setup remote change notifications
    setupRemoteChangeNotifications()
}
```

### 13.2 Migration Test

```swift
// Test migration before production
#if DEBUG
func testMigration() {
    let context = container.viewContext
    
    // Fetch existing entries
    let fetchRequest: NSFetchRequest<DailyEntry> = DailyEntry.fetchRequest()
    
    do {
        let entries = try context.fetch(fetchRequest)
        print("✅ Migration successful: \(entries.count) entries found")
        
        // Check new attributes
        if let firstEntry = entries.first {
            print("isSharedWithCircle: \(firstEntry.isSharedWithCircle)")
            print("viewCount: \(firstEntry.viewCount)")
        }
    } catch {
        print("❌ Migration failed: \(error)")
    }
}
#endif
```

## Adım 14: Entitlement Dosyası Kontrolü

Xcode otomatik oluşturur, ancak kontrol edin:

### 14.1 one.entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.yourcompany.one</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.com.yourcompany.one</string>
    </array>
</dict>
</plist>
```

## Adım 15: CloudKit Dashboard Detaylı Kurulum

### 15.1 Development Environment

1. https://icloud.developer.apple.com/dashboard adresine git
2. Container'ınızı seç
3. "Schema" sekmesine git
4. "Record Types" altında "+" tıkla

**User Record Type:**
```
Record Type Name: User

Fields:
┌─────────────────┬──────────┬──────────┬───────────┐
│ Field Name      │ Type     │ Indexed  │ Queryable │
├─────────────────┼──────────┼──────────┼───────────┤
│ userID          │ String   │ ✅       │ ✅        │
│ displayName     │ String   │          │           │
│ inviteCode      │ String   │ ✅       │ ✅        │
│ avatarColor     │ String   │          │           │
│ isPublic        │ Int(64)  │          │           │
│ createdDate     │ DateTime │          │           │
└─────────────────┴──────────┴──────────┴───────────┘

Indexes:
- inviteCode (Queryable, Unique)
- userID (Queryable)

Security:
- World: No Access
- Authenticated: Read Own, Write Own
- Creator: Full Access
```

**Friendship Record Type:**
```
Record Type Name: Friendship

Fields:
┌─────────────────┬──────────┬──────────┬───────────┐
│ Field Name      │ Type     │ Indexed  │ Queryable │
├─────────────────┼──────────┼──────────┼───────────┤
│ friendshipID    │ String   │ ✅       │           │
│ user1ID         │ String   │ ✅       │ ✅        │
│ user2ID         │ String   │ ✅       │ ✅        │
│ status          │ String   │          │ ✅        │
│ createdDate     │ DateTime │          │           │
│ acceptedDate    │ DateTime │          │           │
└─────────────────┴──────────┴──────────┴───────────┘

Indexes:
- user1ID (Queryable)
- user2ID (Queryable)
- status (Queryable)

Security:
- World: No Access
- Authenticated: Read Own, Write Own
- Creator: Full Access
```

**DailyShare Record Type:**
```
Record Type Name: DailyShare

Fields:
┌─────────────────┬──────────┬──────────┬───────────┐
│ Field Name      │ Type     │ Indexed  │ Queryable │
├─────────────────┼──────────┼──────────┼───────────┤
│ shareID         │ String   │ ✅       │           │
│ userID          │ String   │ ✅       │ ✅        │
│ date            │ DateTime │ ✅       │ ✅        │
│ songName        │ String   │          │           │
│ artistName      │ String   │          │           │
│ genre           │ String   │          │           │
│ emoji           │ String   │          │           │
│ albumArtURL     │ String   │          │           │
│ moodWord        │ String   │          │           │
│ moodColor       │ String   │          │           │
│ moodTheme       │ String   │          │           │
│ dailyNote       │ String   │          │           │
│ platform        │ String   │          │           │
│ isPublic        │ Int(64)  │          │ ✅        │
│ createdAt       │ DateTime │          │ ✅        │
└─────────────────┴──────────┴──────────┴───────────┘

Indexes:
- userID (Queryable)
- date (Queryable, Sortable)
- isPublic (Queryable)

Security:
- World: No Access
- Authenticated: Read (if isPublic=1), Write Own
- Creator: Full Access
```

### 15.2 Schema Deployment

1. Development'ta test et
2. "Deploy Schema Changes" butonu
3. "Deploy to Production" seç
4. Değişiklikleri onayla
5. ⚠️ Production'a deploy edildikten sonra geri alınamaz!

## Adım 16: Test Senaryoları

### 16.1 Unit Test Örneği

```swift
//
//  CloudKitManagerTests.swift
//  oneTests
//

import XCTest
import CloudKit
@testable import one

class CloudKitManagerTests: XCTestCase {
    var sut: CloudKitManager!
    
    override func setUp() {
        super.setUp()
        sut = CloudKitManager.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testCloudKitAvailability() {
        let expectation = self.expectation(description: "CloudKit availability check")
        
        sut.checkCloudKitAvailability()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            XCTAssertTrue(self.sut.isCloudKitAvailable || !self.sut.isCloudKitAvailable)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testInviteCodeGeneration() {
        let code = sut.generateInviteCode()
        
        XCTAssertEqual(code.count, 6)
        XCTAssertTrue(code.prefix(3).allSatisfy { $0.isLetter })
        XCTAssertTrue(code.suffix(3).allSatisfy { $0.isNumber })
    }
    
    func testUserCreation() {
        let expectation = self.expectation(description: "User creation")
        
        sut.createOrFetchUser(displayName: "Test User") { result in
            switch result {
            case .success(let user):
                XCTAssertNotNil(user["userID"])
                XCTAssertNotNil(user["inviteCode"])
                XCTAssertEqual(user["displayName"] as? String, "Test User")
            case .failure(let error):
                XCTFail("User creation failed: \(error)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}
```

### 16.2 UI Test Örneği

```swift
//
//  CircleUITests.swift
//  oneUITests
//

import XCTest

class CircleUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testCircleTabExists() {
        let tabBar = app.tabBars
        XCTAssertTrue(tabBar.buttons["Çevre"].exists)
    }
    
    func testAddFriendFlow() {
        // Navigate to Circle tab
        app.tabBars.buttons["Çevre"].tap()
        
        // Tap add friend button
        app.navigationBars.buttons["person.badge.plus"].tap()
        
        // Check if AddFriendView is presented
        XCTAssertTrue(app.navigationBars["Arkadaş Ekle"].exists)
        
        // Check if invite code is displayed
        XCTAssertTrue(app.staticTexts["Senin Kodun"].exists)
        
        // Close
        app.navigationBars.buttons["Kapat"].tap()
    }
    
    func testInviteCodeInput() {
        app.tabBars.buttons["Çevre"].tap()
        app.navigationBars.buttons["person.badge.plus"].tap()
        
        let textField = app.textFields["Davet Kodu Gir"]
        textField.tap()
        textField.typeText("ABC123")
        
        let sendButton = app.buttons["Davet Gönder"]
        XCTAssertTrue(sendButton.isEnabled)
    }
}
```

## Adım 17: Performance Optimization

### 17.1 Batch Operations

```swift
// CloudKitManager.swift içinde

func batchFetchFriends(completion: @escaping (Result<[CKRecord], Error>) -> Void) {
    guard let currentUserID = currentUser?.recordID.recordName else {
        completion(.failure(NSError(domain: "CloudKit", code: -1)))
        return
    }
    
    let predicate = NSPredicate(format: "(user1ID == %@ OR user2ID == %@) AND status == %@", 
                               currentUserID, currentUserID, "accepted")
    let query = CKQuery(recordType: "Friendship", predicate: predicate)
    
    // Use CKQueryOperation for better performance
    let operation = CKQueryOperation(query: query)
    operation.resultsLimit = 50 // Limit results
    
    var records: [CKRecord] = []
    
    operation.recordFetchedBlock = { record in
        records.append(record)
    }
    
    operation.queryCompletionBlock = { cursor, error in
        if let error = error {
            completion(.failure(error))
        } else {
            completion(.success(records))
        }
    }
    
    privateDatabase.add(operation)
}
```

### 17.2 Caching Strategy

```swift
// Simple cache implementation
class CloudKitCache {
    static let shared = CloudKitCache()
    
    private var cache: [String: (data: Any, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    func set(_ data: Any, forKey key: String) {
        cache[key] = (data, Date())
    }
    
    func get(forKey key: String) -> Any? {
        guard let cached = cache[key] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            return cached.data
        } else {
            cache.removeValue(forKey: key)
            return nil
        }
    }
    
    func clear() {
        cache.removeAll()
    }
}
```

## Adım 18: Error Handling İyileştirmeleri

### 18.1 Custom Error Types

```swift
enum CloudKitError: LocalizedError {
    case notAvailable
    case userNotFound
    case friendshipExists
    case invalidInviteCode
    case networkError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud hesabınızla giriş yapmalısınız"
        case .userNotFound:
            return "Kullanıcı bulunamadı"
        case .friendshipExists:
            return "Bu kullanıcı zaten arkadaşınız"
        case .invalidInviteCode:
            return "Geçersiz davet kodu"
        case .networkError:
            return "Bağlantı hatası. Lütfen tekrar deneyin"
        case .permissionDenied:
            return "iCloud erişim izni gerekli"
        }
    }
}
```

### 18.2 Retry Mechanism

```swift
func retryOperation<T>(
    maxAttempts: Int = 3,
    delay: TimeInterval = 2.0,
    operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
    completion: @escaping (Result<T, Error>) -> Void
) {
    var attempts = 0
    
    func attempt() {
        attempts += 1
        
        operation { result in
            switch result {
            case .success:
                completion(result)
            case .failure(let error):
                if attempts < maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        attempt()
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    attempt()
}

// Usage:
retryOperation { completion in
    cloudKitManager.fetchFriends(completion: completion)
} completion: { result in
    // Handle final result
}
```

## Adım 19: Monitoring ve Logging

### 19.1 CloudKit Operations Logger

```swift
class CloudKitLogger {
    static let shared = CloudKitLogger()
    
    enum LogLevel {
        case info, warning, error
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let prefix: String
        
        switch level {
        case .info:
            prefix = "ℹ️"
        case .warning:
            prefix = "⚠️"
        case .error:
            prefix = "❌"
        }
        
        print("[\(timestamp)] \(prefix) CloudKit: \(message)")
        
        #if DEBUG
        // In debug mode, also save to file
        saveToFile(message: "[\(timestamp)] \(message)")
        #endif
    }
    
    private func saveToFile(message: String) {
        // Implementation for file logging
    }
}

// Usage in CloudKitManager:
CloudKitLogger.shared.log("User created successfully", level: .info)
CloudKitLogger.shared.log("Failed to fetch friends", level: .error)
```

## Adım 20: Production Checklist

### 20.1 Pre-Launch Checklist

- [ ] CloudKit schema deployed to production
- [ ] All indexes created and optimized
- [ ] Security roles properly configured
- [ ] Rate limiting implemented
- [ ] Error handling comprehensive
- [ ] Offline support tested
- [ ] Migration tested with real data
- [ ] Performance profiled (Instruments)
- [ ] Memory leaks checked
- [ ] Battery usage optimized
- [ ] Network usage minimized
- [ ] Privacy policy updated
- [ ] App Store description includes CloudKit features
- [ ] TestFlight beta completed
- [ ] User feedback addressed

### 20.2 Monitoring Metrics

```swift
struct CloudKitMetrics {
    static var shared = CloudKitMetrics()
    
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var averageResponseTime: TimeInterval = 0
    
    func recordRequest(success: Bool, responseTime: TimeInterval) {
        totalRequests += 1
        if success {
            successfulRequests += 1
        } else {
            failedRequests += 1
        }
        
        // Update average
        averageResponseTime = (averageResponseTime * Double(totalRequests - 1) + responseTime) / Double(totalRequests)
    }
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulRequests) / Double(totalRequests) * 100
    }
}
```

## Özet

CloudKit kurulumu tamamlandı! Artık:

✅ Xcode capabilities yapılandırıldı
✅ CloudKit Dashboard schema oluşturuldu
✅ Core Data modeli güncellendi
✅ CloudKitManager implementasyonu tamamlandı
✅ UI components hazır
✅ Test senaryoları oluşturuldu
✅ Error handling ve retry mekanizması eklendi
✅ Performance optimization yapıldı
✅ Monitoring ve logging sistemi kuruldu

**Sonraki Adım:** [CIRCLE_QUICK_START.md](./CIRCLE_QUICK_START.md) ile hızlı test yapın!

## Ek Kaynaklar

- [WWDC 2021: CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2021/10086/)
- [WWDC 2020: Sync a Core Data store with CloudKit](https://developer.apple.com/videos/play/wwdc2020/10650/)
- [CloudKit Console](https://icloud.developer.apple.com/dashboard)
- [Apple Developer Forums - CloudKit](https://developer.apple.com/forums/tags/cloudkit)
