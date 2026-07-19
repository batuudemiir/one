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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .bodySM()
                    .foregroundColor(ONETokens.oneInk)
                if let username = user.username {
                    Text("@\(username)")
                        .monoLabel(tracking: 0.3)
                        .foregroundColor(ONETokens.oneAsh)
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
                    .foregroundColor(ONETokens.oneCream)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(ONETokens.oneInk))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.vertical, 6)
    }
}
