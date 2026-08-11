//
//  ProfileFormView.swift
//  one
//
//  Profil oluşturma / düzenleme formu — yeni BeReal-tarzı tasarım.
//  Dashboard ile tutarlı: full-width hero (foto/gradient + alt scrim),
//  altında inline form alanları, en altta kaydet butonu.
//

import SwiftUI
import PhotosUI

struct ProfileFormView: View {
    @ObservedObject var vm: ProfileViewModel
    var isFromTab: Bool
    var onDismiss: () -> Void

    @FocusState private var focusedField: ProfileField?

    enum ProfileField {
        case displayName, username
    }

    private var profileColor: Color { Color(hex: vm.selectedAvatarColor) }
    private var isDark: Bool { vm.isDarkMode }

    private var screenBG: Color { isDark ? Color.black : ONEBrand.bone }
    private var cardBG: Color { isDark ? Color.white.opacity(0.07) : V3Tokens.surface.opacity(0.65) }
    private var cardBorder: Color { isDark ? Color.clear : ONETokens.oneSilver }
    private var primaryText: Color { isDark ? Color.white : ONETokens.oneInk }
    private var secondaryText: Color { isDark ? Color.white.opacity(0.55) : ONETokens.oneAsh }
    private var sectionHeader: Color { isDark ? Color.white.opacity(0.40) : ONETokens.oneCharcoal }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    formHero
                    formFields
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                    Spacer().frame(height: 120)
                }
            }
            .background(screenBG)
            .ignoresSafeArea(edges: .top)
            .onTapGesture { focusedField = nil }

            // Top bar: kapat (sol), başlık (orta — implicit)
            if isFromTab {
                HStack {
                    Button(action: {
                        ONEHaptics.moodSelected()
                        withAnimation(ONEAnimation.cardSpring) {
                            vm.isEditingFromTab = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .liquidGlass(
                                tint: Color.black.opacity(0.30),
                                interactive: true,
                                in: Circle()
                            )
                    }
                    .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 56)
            }
        }
    }

    // MARK: - Hero (stretchy, same DNA as dashboard)

    private var formHero: some View {
        GeometryReader { proxy in
            let baseHeight: CGFloat = 360
            let minY = proxy.frame(in: .global).minY
            let extra = max(0, minY)
            let height = baseHeight + extra

            ZStack(alignment: .bottomLeading) {
                // Arka plan: foto veya gradient
                if let img = vm.profileImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: height)
                        .clipped()
                } else {
                    heroFallback
                        .frame(width: proxy.size.width, height: height)
                }

                // Scrim
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.10), location: 0.55),
                        .init(color: .black.opacity(0.62), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: height)
                .allowsHitTesting(false)

                // İsim/başlık + foto değiştirme CTA
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.isEditMode
                             ? NSLocalizedString("profile.editProfile", comment: "")
                             : NSLocalizedString("profile.createProfile", comment: ""))
                            .monoLabel(tracking: 1.6)
                            .foregroundColor(.white.opacity(0.78))
                        Text(vm.displayName.isEmpty
                             ? NSLocalizedString("profile.namePlaceholder", comment: "")
                             : vm.displayName)
                            .font(.system(size: 28, weight: .semibold))
                            .tracking(-0.4)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 2)
                    }

                    Spacer()

                    // Foto değiştir CTA (Liquid Glass — kameralı)
                    PhotosPicker(selection: $vm.selectedPhotoItem, matching: .images) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(NSLocalizedString("profile.changePhoto", comment: ""))
                                .monoLabel(tracking: 0.6)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .liquidGlass(
                            tint: Color.black.opacity(0.30),
                            interactive: true,
                            in: Capsule()
                        )
                    }
                    .onChange(of: vm.selectedPhotoItem) { _, newItem in
                        guard let newItem else { return }
                        Task { await vm.loadAndSaveProfilePhoto(from: newItem) }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
            .frame(width: proxy.size.width, height: height)
            .clipped()
            .offset(y: -extra)
        }
        .frame(height: 360)
    }

    private var heroFallback: some View {
        let initial = vm.displayName.isEmpty ? "•" : vm.displayName.prefix(1).uppercased()
        return ZStack {
            LinearGradient(
                colors: [
                    profileColor.opacity(0.92),
                    profileColor.opacity(0.55),
                    profileColor.opacity(0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(profileColor.opacity(0.45))
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: -80, y: -100)
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 160, height: 160)
                .blur(radius: 60)
                .offset(x: 90, y: 50)

            Text(initial)
                .displayXL()
                .fontWeight(.semibold)
                .italic()
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 4)
        }
    }

    // MARK: - Form fields

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Name
            fieldGroup(title: NSLocalizedString("profile.name", comment: "")) {
                HStack(spacing: 10) {
                    Image(systemName: "person")
                        .font(.system(size: 14))
                        .foregroundColor(focusedField == .displayName ? profileColor : secondaryText)
                        .frame(width: 20)
                    TextField(NSLocalizedString("profile.namePlaceholder", comment: ""), text: $vm.displayName)
                        .focused($focusedField, equals: .displayName)
                        .bodyLG()
                        .fontWeight(.medium)
                        .foregroundColor(primaryText)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .username }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(cardBG)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            focusedField == .displayName
                                ? profileColor.opacity(0.5)
                                : cardBorder,
                            lineWidth: 1
                        )
                )
            }

            // Username
            fieldGroup(title: NSLocalizedString("profile.username", comment: "")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("@")
                            .bodyLG()
                            .fontWeight(.medium)
                            .foregroundColor(focusedField == .username ? profileColor : secondaryText)
                        TextField("kullaniciadi", text: $vm.username)
                            .focused($focusedField, equals: .username)
                            .bodyLG()
                            .foregroundColor(primaryText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                            .onChange(of: vm.username) { _, newValue in
                                let lowercased = newValue.lowercased()
                                if lowercased != newValue { vm.username = lowercased }
                                vm.checkUsernameAvailability(newValue)
                            }
                        if vm.isCheckingUsername {
                            ProgressView().scaleEffect(0.7)
                        } else if let isAvailable = vm.isUsernameAvailable {
                            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(isAvailable ? ONETokens.oneGreen : ONETokens.oneRed)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                focusedField == .username ? profileColor.opacity(0.5) :
                                vm.isUsernameAvailable == true ? ONETokens.oneGreen.opacity(0.3) :
                                vm.isUsernameAvailable == false ? ONETokens.oneRed.opacity(0.3) :
                                cardBorder,
                                lineWidth: 1
                            )
                    )

                    if let message = vm.usernameValidationMessage {
                        Text(message)
                            .monoLabel()
                            .foregroundColor(vm.isUsernameAvailable == true ? ONETokens.oneGreen : ONETokens.oneRed)
                            .padding(.leading, 4)
                    }
                }
            }

            // Color picker
            fieldGroup(title: NSLocalizedString("profile.color", comment: "")) {
                HStack(spacing: 10) {
                    ForEach(vm.avatarColors, id: \.self) { color in
                        Button(action: {
                            ONEHaptics.moodSelected()
                            withAnimation(ONEAnimation.micro) {
                                vm.selectedAvatarColor = color
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(
                                        width: vm.selectedAvatarColor == color ? 34 : 28,
                                        height: vm.selectedAvatarColor == color ? 34 : 28
                                    )
                                if vm.selectedAvatarColor == color {
                                    Circle()
                                        .stroke(Color.white.opacity(isDark ? 0.5 : 0.9), lineWidth: 2.5)
                                        .frame(width: 28, height: 28)
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(cardBG)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(cardBorder, lineWidth: 1))
            }

            // Kaydet
            saveButton
                .padding(.top, 6)

            if let error = vm.errorMessage {
                Text(error)
                    .monoSM()
                    .foregroundColor(ONETokens.oneRed)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .monoBase(tracking: 1.5)
                .foregroundColor(sectionHeader)
                .padding(.leading, 4)
            content()
        }
    }

    private var saveButton: some View {
        Button(action: {
            vm.saveProfile { success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if isFromTab {
                            withAnimation(ONEAnimation.cardSpring) {
                                vm.isEditingFromTab = false
                                vm.showSuccess = false
                            }
                        } else {
                            onDismiss()
                        }
                    }
                }
            }
        }) {
            ZStack {
                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if vm.showSuccess {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text(NSLocalizedString("addFriend.ok", comment: ""))
                    }
                } else {
                    Text(vm.isEditMode
                         ? NSLocalizedString("general.save", comment: "")
                         : NSLocalizedString("profile.createProfile", comment: ""))
                }
            }
            .bodySMMedium()
            .foregroundColor(
                vm.showSuccess ? ONETokens.oneGreen :
                vm.canSaveProfile ? .white :
                ONETokens.oneAsh
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        vm.showSuccess
                            ? ONETokens.oneGreen.opacity(0.12)
                            : vm.canSaveProfile
                                ? profileColor
                                : (isDark ? Color.white.opacity(0.08) : V3Tokens.wash)
                    )
            )
        }
        .disabled(!vm.canSaveProfile || vm.isLoading)
    }
}
