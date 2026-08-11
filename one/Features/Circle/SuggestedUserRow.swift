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

    private var initial: String { String(user.displayName.prefix(1)).uppercased() }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: user.avatarColorHex))
                    .frame(width: 40, height: 40)
                Text(initial)
                    .font(V3Typography.sans(15, weight: .medium))
                    .foregroundColor(.white)
            }

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
                    Text("• \(user.mutualFriendCount) ortak")
                        .monoLabel(tracking: 0.3)
                        .foregroundColor(ONETokens.oneMist)
                }
            }

            Spacer()

            Button(action: onAdd) {
                Text("+ Ekle")
                    .monoLabel(tracking: 0.5)
                    .foregroundColor(ONEBrand.bone)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(V3Tokens.ink))
            }
            .buttonStyle(ScaleButtonStyle())
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

    private var initial: String { String(user.displayName.prefix(1)).uppercased() }

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(Color(hex: user.avatarColorHex))
                    .frame(width: 40, height: 40)
                Text(initial)
                    .font(V3Typography.sans(14, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(user.displayName)
                .font(V3Typography.sans(12.5, weight: .semibold))
                .foregroundColor(V3Tokens.ink)
                .lineLimit(1)

            Text(user.mutualFriendCount > 0
                 ? String(format: NSLocalizedString("addFriend.mutualCount", comment: ""), user.mutualFriendCount)
                 : " ")
                .font(.system(size: 10))
                .foregroundColor(V3Tokens.faintText)
                .lineLimit(1)

            Button(action: onAdd) {
                Text(NSLocalizedString(sent ? "addFriend.sent" : "addFriend.addAction", comment: ""))
                    .font(V3Typography.sans(11, weight: .semibold))
                    .foregroundColor(sent ? ONETokens.oneAsh : ONEBrand.bone)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(sent ? V3Tokens.ink.opacity(0.10) : V3Tokens.ink)
                    )
            }
            .buttonStyle(.plain)
            .disabled(sent)
        }
        .frame(width: 104)
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 11)
        .oneCardBackground(radius: ONETokens.radiusCardLg, opacity: 0.78)
    }
}
