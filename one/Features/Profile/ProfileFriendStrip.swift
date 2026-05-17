//
//  ProfileFriendStrip.swift
//  one
//
//  Feature: ui-consistency-and-accessibility-sweep (Task 3.3)
//
//  Friend count chip + dynamic "Profili Paylaş" (share profile) button + edit
//  avatar action row, extracted from `ProfileDashboardView`. Pure composition
//  — no behavior changes.
//

import SwiftUI

/// Horizontal strip beneath the hero: friend count → share profile → edit
/// avatar. Bindings let the parent dashboard own the sheet-presentation state
/// so public navigation entry points remain unchanged (Req 4.4).
struct ProfileFriendStrip: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.profilePalette) private var palette

    /// Opens the friend list sheet when the friend count chip is tapped.
    @Binding var showFriendsList: Bool
    /// Opens the invite share sheet when the share button is tapped.
    @Binding var showShareSheet: Bool

    private var profileColor: Color { Color(hex: vm.selectedAvatarColor) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button(action: {
                    ONEHaptics.tabSwitch()
                    showFriendsList = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .bodyXS()
                            .foregroundColor(palette.secondaryText)
                        Text(String(format: NSLocalizedString("profile.friendsCount", comment: ""), vm.friendCount))
                            .bodySMMedium()
                            .foregroundColor(palette.primaryText)
                        Image(systemName: "chevron.right")
                            .monoMicro()
                            .foregroundColor(palette.tertiaryText)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("profile.friendsList.a11y", comment: ""))

                Spacer()

                if !vm.inviteCode.isEmpty && vm.inviteCode != "------" {
                    HStack(spacing: 6) {
                        Circle().fill(profileColor).frame(width: 5, height: 5)
                        Text(vm.inviteCode)
                            .monoBase(tracking: 1.6)
                            .foregroundColor(palette.secondaryText)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(profileColor.opacity(vm.isDarkMode ? 0.16 : 0.10))
                    )
                }
            }

            HStack(spacing: 10) {
                dynamicShareButton

                Button(action: {
                    ONEHaptics.tabSwitch()
                    withAnimation(ONEAnimation.cardSpring) { vm.isEditingFromTab = true }
                }) {
                    Image(systemName: "pencil")
                        .bodySMMedium()
                        .foregroundColor(palette.primaryText)
                        .frame(width: 46, height: 46)
                        .liquidGlass(
                            tint: vm.isDarkMode
                                ? Color.black.opacity(0.40)
                                : ONETokens.oneInk.opacity(0.14),
                            interactive: true,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("profile.editProfile.a11y", comment: ""))
            }
        }
    }

    /// Dinamik "Profili Paylaş" butonu — solda mini avatar (mood-tinted),
    /// ortada "Profili Paylaş" + davet kodunun mini önizlemesi, sağda
    /// share oku. Mood color glow ile canlı duruyor.
    private var dynamicShareButton: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            showShareSheet = true
        }) {
            HStack(spacing: 12) {
                // Mini avatar circle (mood-tinted)
                ZStack {
                    Circle()
                        .fill(profileColor.opacity(vm.isDarkMode ? 0.30 : 0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: "paperplane.fill")
                        .monoBase()
                        .foregroundColor(profileColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(NSLocalizedString("profile.shareProfile", comment: ""))
                        .bodySMMedium()
                        .foregroundColor(palette.primaryText)
                    Text(NSLocalizedString("profile.shareProfile.hint", comment: ""))
                        .monoLabel(tracking: 0.4)
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .monoSM()
                    .foregroundColor(profileColor)
                    .padding(8)
                    .background(Circle().fill(profileColor.opacity(0.10)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            // Liquid Glass — tema bazlı koyu mood-tinted
            .liquidGlass(
                tint: vm.isDarkMode
                    ? profileColor.opacity(0.32)
                    : profileColor.opacity(0.22),
                interactive: true,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
