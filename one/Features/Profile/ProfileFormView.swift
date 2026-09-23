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
    var onDismiss: () -> Void

    @FocusState private var focusedField: ProfileField?

    enum ProfileField {
        case displayName, username
    }

    private var profileColor: Color { Color(hex: vm.selectedAvatarColor) }
    /// Bu ekran eskiden kendi karanlık mod paletini elle kuruyordu
    /// (`vm.isDarkMode ? Color.black : ONEBrand.bone` gibi altı ayrı satır).
    /// Token sisteminin yanında ikinci bir renk sistemiydi ve ondan bağımsız
    /// kayıyordu: `V3Tokens` zaten `UITraitCollection` üzerinden adaptif,
    /// yani doğru cevap her koşulda "token'ı kullan".
    ///
    /// `isDark` yalnız iki yerde kaldı, oralarda token değil **opaklık**
    /// seçiliyor — onun adaptif karşılığı yok.
    private var isDark: Bool { vm.isDarkMode }

    private var screenBG: Color { V3Tokens.paper }
    private var cardBG: Color { V3Tokens.surface.opacity(0.65) }
    private var cardBorder: Color { V3Tokens.hairline }
    private var primaryText: Color { V3Tokens.ink }
    private var secondaryText: Color { V3Tokens.mutedText }
    private var sectionHeader: Color { V3Tokens.faintText }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    formHero
                    formFields
                        .padding(.horizontal, V3Tokens.spacingXL)
                        .padding(.top, V3Tokens.spacingXL)
                    Spacer().frame(height: 120)
                }
            }
            .background(screenBG)
            .ignoresSafeArea(edges: .top)
            .onTapGesture { focusedField = nil }

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
                    VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
                        Text(vm.isEditMode
                             ? NSLocalizedString("profile.editProfile", comment: "")
                             : NSLocalizedString("profile.createProfile", comment: ""))
                            .monoLabel(tracking: 1.6)
                            .foregroundColor(V3Tokens.darkText.opacity(0.78))
                        Text(vm.displayName.isEmpty
                             ? NSLocalizedString("profile.namePlaceholder", comment: "")
                             : vm.displayName)
                            // Kullanıcının kendi adı — marka yüzü. V3ProfileView
                            // de adı Archivo ile çiziyor; burada 28pt sistem
                            // sans'tı, yani aynı kişi iki ekranda iki yüzle.
                            .displayHero()
                            .foregroundColor(V3Tokens.darkText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 2)
                    }

                    Spacer()

                    // Foto değiştir CTA (Liquid Glass — kameralı)
                    PhotosPicker(selection: $vm.selectedPhotoItem, matching: .images) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .iconSM(weight: .semibold)
                            Text(NSLocalizedString("profile.changePhoto", comment: ""))
                                .monoLabel(tracking: 0.6)
                        }
                        .foregroundColor(V3Tokens.darkText)
                        .padding(.horizontal, V3Tokens.spacingMD)
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
                .padding(.horizontal, V3Tokens.spacingXL)
                .padding(.bottom, V3Tokens.spacingXL)
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
                        .iconMD()
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
                .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusCard))
                .overlay(
                    RoundedRectangle(cornerRadius: V3Tokens.radiusCard)
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
                    HStack(spacing: V3Tokens.spacingXS) {
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
                            V3Loading(.inline)
                        } else if let isAvailable = vm.isUsernameAvailable {
                            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .iconMD()
                                .foregroundColor(isAvailable ? V3Tokens.success : V3Tokens.danger)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusCard))
                    .overlay(
                        RoundedRectangle(cornerRadius: V3Tokens.radiusCard)
                            .stroke(
                                focusedField == .username ? profileColor.opacity(0.5) :
                                vm.isUsernameAvailable == true ? V3Tokens.success.opacity(0.3) :
                                vm.isUsernameAvailable == false ? V3Tokens.danger.opacity(0.3) :
                                cardBorder,
                                lineWidth: 1
                            )
                    )

                    if let message = vm.usernameValidationMessage {
                        Text(message)
                            .monoLabel()
                            .foregroundColor(vm.isUsernameAvailable == true ? V3Tokens.success : V3Tokens.danger)
                            .padding(.leading, V3Tokens.spacingXS)
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
                        .buttonStyle(.onePressable)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(cardBG)
                .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusCard))
                .overlay(RoundedRectangle(cornerRadius: V3Tokens.radiusCard).stroke(cardBorder, lineWidth: 1))
            }

            // Kaydet
            saveButton
                .padding(.top, 6)

            if let error = vm.errorMessage {
                Text(error)
                    .monoSM()
                    .foregroundColor(V3Tokens.danger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, V3Tokens.spacingXS)
            }
        }
    }

    @ViewBuilder
    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            Text(title)
                .monoBase(tracking: 1.5)
                .foregroundColor(sectionHeader)
                .padding(.leading, V3Tokens.spacingXS)
            content()
        }
    }

    private var saveButton: some View {
        Button(action: {
            vm.saveProfile { success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onDismiss()
                    }
                }
            }
        }) {
            ZStack {
                if vm.isLoading {
                    V3Loading(.media)
                } else if vm.showSuccess {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .iconSM(weight: .bold)
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
                vm.showSuccess ? V3Tokens.success :
                vm.canSaveProfile ? .white :
                V3Tokens.mutedText
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, V3Tokens.spacingLG)
            .background(
                RoundedRectangle(cornerRadius: V3Tokens.radiusCard)
                    .fill(
                        vm.showSuccess
                            ? V3Tokens.success.opacity(0.12)
                            : vm.canSaveProfile
                                ? profileColor
                                : (isDark ? Color.white.opacity(0.08) : V3Tokens.wash)
                    )
            )
        }
        .buttonStyle(.onePressable)
        .disabled(!vm.canSaveProfile || vm.isLoading)
    }
}
