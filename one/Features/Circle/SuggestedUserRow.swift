import SwiftUI

struct SuggestedUser: Identifiable {
    let id: String
    let displayName: String
    let username: String?
    let avatarColorHex: String
    let mutualFriendCount: Int
}

struct SuggestedUserRow: View {
    let user: SuggestedUser
    var onAdd: () -> Void


    var body: some View {
        HStack(spacing: V3Tokens.spacingMD) {
            V3PersonAvatar(name: user.displayName, colorHex: user.avatarColorHex, size: .medium)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .bodySM()
                    .foregroundColor(V3Tokens.ink)
                if let username = user.username {
                    Text("@\(username)")
                        .monoLabel(tracking: 0.3)
                        .foregroundColor(V3Tokens.mutedText)
                }
                if user.mutualFriendCount > 0 {
                    Text(String(format: NSLocalizedString("circle.mutualCount", comment: ""), user.mutualFriendCount))
                        .monoLabel(tracking: 0.3)
                        .foregroundColor(V3Tokens.mutedText)
                }
            }

            Spacer()

            Button(action: onAdd) {
                Text(NSLocalizedString("circle.addShort", comment: ""))
                    .monoLabel(tracking: 0.5)
                    .foregroundColor(ONEBrand.bone)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(V3Tokens.ink))
            }
            .buttonStyle(.onePressable)
        }
        .padding(.vertical, 6)
    }
}

/// Prototipteki `.sug` — "rehberinde ONE'da olanlar" yatay şeridinin kartı.
/// Dikey `SuggestedUserRow`'dan farkı: dar (104pt), yatay kaydırılan bir
/// şeritte duruyor ve "ekle" → "gönderildi"ye dönüşüyor.
struct QuickSuggestCard: View {
    let user: SuggestedUser
    let sent: Bool
    var onAdd: () -> Void


    var body: some View {
        VStack(spacing: 7) {
            V3PersonAvatar(name: user.displayName, colorHex: user.avatarColorHex, size: .medium)

            Text(user.displayName)
                .bodyMicroSemibold()
                .foregroundColor(V3Tokens.ink)
                .lineLimit(1)

            Text(user.mutualFriendCount > 0
                 ? String(format: NSLocalizedString("addFriend.mutualCount", comment: ""), user.mutualFriendCount)
                 : " ")
                .bodyMicro()
                .foregroundColor(V3Tokens.faintText)
                .lineLimit(1)

            Button(action: onAdd) {
                Text(NSLocalizedString(sent ? "addFriend.sent" : "addFriend.addAction", comment: ""))
                    .bodyMicroSemibold()
                    .foregroundColor(sent ? V3Tokens.mutedText : ONEBrand.bone)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                            .fill(sent ? V3Tokens.ink.opacity(0.10) : V3Tokens.ink)
                    )
            }
            .buttonStyle(.onePressable)
            .disabled(sent)
        }
        .frame(width: 104)
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 11)
        .oneCardBackground(radius: V3Tokens.radiusCard)
    }
}
