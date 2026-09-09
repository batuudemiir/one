import SwiftUI
import PhotosUI

/// Adım 2 — Not (140 char), fotoğraf, şarkı, kapsam. Hepsi opsiyonel.
///
/// v3.1 layout (Öneri B — katmanlı akış):
///  - Üst hero (mood color, ~%40 ekran): back chip + mood label 56pt + tarih micro.
///  - Alt kağıt kart (paper, üst köşeler 32pt yuvarlak, hero'ya -20 offset ile bindirilmiş):
///    Not TextEditor (auto-grow) + 3 küçük aksiyon chip'i (Foto/Şarkı/Kimde) + footer.
///  - Fotoğraf/şarkı/scope hepsi sheet'ten seçiliyor → ekran her cihazda scroll'suz sığar.
///  - Chip filled state → aynı sheet'ten değiştir/kaldır.
struct V3DetailsStepView: View {
    let mood: V3Mood

    @Binding var note: String
    @Binding var photoEnabled: Bool
    @Binding var pickedPhoto: UIImage?
    @Binding var songEnabled: Bool
    @Binding var pickedSong: SongResult?
    @Binding var scope: MomentScope

    let onBack: () -> Void
    let onSave: () -> Void

    /// Doldurulan gün — past-day akışında container geçmiş tarihi verir.
    /// Nil ise bugün varsayılır.

    /// Container namespace — pick adımındaki seçili tile'ın renk yüzeyi bu
    /// hero'ya interpole edilir. Nil geçilirse (preview/legacy), sade renk.
    var moodMorph: Namespace.ID? = nil

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showPhotoPicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var showSongSearch: Bool = false
    @State private var showPhotoSourceSheet: Bool = false
    @State private var showScopeSheet: Bool = false

    /// Kaynak sayfası kapanınca ne açılacak.
    ///
    /// Kapanmakta olan bir sheet'in üstüne yenisini sunmak SwiftUI'de sessizce
    /// düşüyor; eskiden bu `asyncAfter(0.32)` ile aşılıyordu — yani kullanıcı
    /// "galeri"ye basıyor ve üçte bir saniye hiçbir şey olmuyordu. Niyeti
    /// burada tutup `onDismiss`'te açmak aynı sorunu zamanlayıcı tahmini
    /// yerine gerçek kapanma olayına bağlıyor.
    private enum PendingPhotoSource { case gallery, camera }
    @State private var pendingPhotoSource: PendingPhotoSource? = nil

    @FocusState private var noteFocused: Bool

    private let maxNoteLength = 140

    var body: some View {
        GeometryReader { geo in
            // Ekran yüksekliğinin %38'i hero — footer + note + chips için %62 kalır.
            let heroHeight = max(220, geo.size.height * 0.38)

            VStack(spacing: 0) {
                heroSection(height: heroHeight)
                bottomCard
            }
        }
        // Container 24pt horizontal padding uygular; hero full-bleed olsun diye
        // negatif margin ile o padding'i iptal ediyoruz.
        .padding(.horizontal, -24)
        .ignoresSafeArea(.keyboard)
        .onChange(of: note) { _, newValue in
            if newValue.count > maxNoteLength {
                note = String(newValue.prefix(maxNoteLength))
            }
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run {
                        pickedPhoto = ui
                        photoEnabled = true
                        AppAnalytics.shared.track(.photoAdded(method: "library"))
                    }
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            V3CameraView(
                image: Binding(
                    get: { pickedPhoto },
                    set: { new in
                        pickedPhoto = new
                        if new != nil {
                            photoEnabled = true
                            AppAnalytics.shared.track(.photoAdded(method: "camera"))
                        }
                    }
                ),
                moodColor: mood.color
            )
        }
        .sheet(isPresented: $showSongSearch) {
            V3SongPicker(mood: mood) { song in
                pickedSong = song
                songEnabled = true
                showSongSearch = false
            }
        }
        .v3Sheet()
        .sheet(isPresented: $showPhotoSourceSheet, onDismiss: {
            // Kapanma bitti — sıradakini şimdi aç. Kullanıcı sayfayı aşağı
            // sürükleyerek kapatırsa niyet nil kalır ve hiçbir şey açılmaz.
            switch pendingPhotoSource {
            case .gallery: showPhotoPicker = true
            case .camera:  showCamera = true
            case nil:      break
            }
            pendingPhotoSource = nil
        }) {
            V3DetailsPhotoSourceSheet(
                accent: mood.color,
                hasPhoto: pickedPhoto != nil,
                onGallery: {
                    pendingPhotoSource = .gallery
                    showPhotoSourceSheet = false
                },
                onCamera: {
                    pendingPhotoSource = .camera
                    showPhotoSourceSheet = false
                },
                onRemove: {
                    showPhotoSourceSheet = false
                    pickedPhoto = nil
                    photoEnabled = false
                    photoPickerItem = nil
                }
            )
            .v3Sheet(detents: [.height(pickedPhoto == nil ? 260 : 320)])
        }
        .sheet(isPresented: $showScopeSheet) {
            V3ScopeSheet(scope: $scope, moodColor: mood.color)
                // Sabit yükseklik yerine .medium — Dynamic Type Large'ta içerik büyür.
                .v3Sheet(detents: [.medium])
        }
    }

    // MARK: - Hero (mood color)

    private func heroSection(height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Solid mood color — subtle gradient göz için hiçbir şey eklemiyordu.
            // moodMorph verilmişse pick adımındaki seçili tile buradaki yüzeye
            // interpole olur; kullanıcı "rengimi taşıdım" hissi kurar.
            Group {
                if let ns = moodMorph {
                    mood.color
                        .matchedGeometryEffect(id: "moodSurface", in: ns, isSource: true)
                } else {
                    mood.color
                }
            }

            // Top-left: back chip.
            VStack {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .iconSM(weight: .semibold)
                            Text(NSLocalizedString("entry.changeColour", comment: ""))
                                .bodyXSSemibold()
                        }
                        .foregroundColor(mood.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(mood.ink.opacity(0.12))
                                .overlay(Capsule().stroke(mood.ink.opacity(0.18), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.onePressable)
                    .accessibilityLabel(NSLocalizedString("entry.a11y.backToColor", comment: ""))
                    Spacer()
                    Text(dateLabel)
                        .monoLabel(weight: .regular)
                        .tracking(1.5)
                        .textCase(.uppercase)   // TR locale-safe uppercase
                        .foregroundColor(mood.ink.opacity(0.7))
                        .accessibilityLabel(String(format: NSLocalizedString("entry.a11y.date", comment: ""), dateLabelSpoken))
                }
                .padding(.horizontal, V3Tokens.channel)
                .padding(.top, 18)
                Spacer()
            }

            // Bottom-left: mood label. Alt başlık yok — bu ölçekte (56pt display)
            // ikinci bir satır kartın dengesini bozuyor; anlam VoiceOver
            // değerinde (`mood.meaning`) taşınıyor.
            Text(mood.label.lowercased())
                .font(V3Typography.display(56, weight: .heavy))
                .tracking(-1.8)
                .foregroundColor(mood.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, V3Tokens.channel)
                .padding(.bottom, 44)   // Kart bindirmesi için ekstra boşluk
                .accessibilityLabel(String(format: NSLocalizedString("entry.a11y.todayColor", comment: ""), mood.label))
                .accessibilityAddTraits(.isHeader)
        }
        .frame(height: height)
        .animation(ONEAnimation.easingColor, value: mood)
    }

    // MARK: - Bottom card (paper)

    private var bottomCard: some View {
        VStack(spacing: 0) {
            noteBlock
                .padding(.horizontal, V3Tokens.spacingXL)
                .padding(.top, V3Tokens.spacingXL)

            extrasRow
                .padding(.horizontal, V3Tokens.spacingXL)
                .padding(.top, V3Tokens.spacingLG)

            Spacer(minLength: 12)

            footer
                .padding(.horizontal, V3Tokens.spacingXL)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            V3Tokens.paper
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 32,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 32,
                    style: .continuous
                ))
                .shadow(color: .black.opacity(0.10), radius: 20, y: -6)
        )
        // Hero'ya bindirme layout hesabına dahil — .offset değil .padding.
        .padding(.top, -22)
    }

    // MARK: - Note block

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            HStack(alignment: .firstTextBaseline) {
                Text(NSLocalizedString("entry.note.title", comment: ""))
                    .font(V3Typography.display(22, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundColor(V3Tokens.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(note.count)/\(maxNoteLength)")
                    .monoLabel(weight: .regular)
                    .tracking(1.0)
                    .foregroundColor(V3Tokens.ghostText)
                    .accessibilityLabel(String(format: NSLocalizedString("entry.a11y.noteCount", comment: ""), note.count, maxNoteLength))
            }

            // TextField axis:.vertical → iOS 16+ auto-height, 3-4 satır aralığı.
            // maxHeight cap küçük ekran (iPhone SE) taşmasını önler.
            TextField(NSLocalizedString("entry.note.placeholder", comment: ""), text: $note, axis: .vertical)
                .lineLimit(3...4)
                .bodyLG()
                .foregroundColor(V3Tokens.ink)
                .tint(mood.color)
                .padding(14)
                .frame(maxHeight: 140)
                .background(
                    RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                        .fill(V3Tokens.wash)
                        .overlay(
                            RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                                .stroke(noteFocused ? mood.color.opacity(0.5) : V3Tokens.hairline, lineWidth: 1)
                        )
                )
                .focused($noteFocused)
                .animation(ONEAnimation.easing, value: noteFocused)
                .accessibilityLabel(String(format: NSLocalizedString("entry.a11y.noteField", comment: ""), maxNoteLength))
        }
    }

    // MARK: - Extras row (3 chips)

    private var extrasRow: some View {
        HStack(spacing: V3Tokens.spacingSM) {
            actionChip(
                systemImage: "camera",
                label: NSLocalizedString("entry.chip.photo", comment: ""),
                filled: pickedPhoto != nil,
                a11yState: pickedPhoto != nil ? NSLocalizedString("entry.state.selected", comment: "") : NSLocalizedString("entry.state.empty", comment: ""),
                accent: mood.color
            ) {
                // Foto yoksa doğrudan vizör açılıyor — araya "Kamera mı,
                // galeri mi" sorusu girmiyor. Galeri zaten vizörün kendi alt
                // barında duruyor, yani seçenek kaybolmuyor, bir dokunuş
                // öteye gidiyor. Kamera-öncelikli his, kamera-zorunlu değil.
                //
                // Foto varsa sayfa kalıyor: orada asıl iş değiştirmek ya da
                // kaldırmak, ikisi de vizörün içinde yaşamıyor.
                if pickedPhoto == nil {
                    showCamera = true
                } else {
                    showPhotoSourceSheet = true
                }
            }

            actionChip(
                systemImage: "music.note",
                label: NSLocalizedString("entry.chip.song", comment: ""),
                filled: pickedSong != nil,
                a11yState: pickedSong != nil ? NSLocalizedString("entry.state.selected", comment: "") : NSLocalizedString("entry.state.empty", comment: ""),
                accent: mood.color
            ) {
                showSongSearch = true
            }

            actionChip(
                systemImage: scope == .friends ? "person.2.fill" : "lock.fill",
                label: scope == .friends ? NSLocalizedString("entry.chip.circle", comment: "") : NSLocalizedString("entry.chip.private", comment: ""),
                filled: scope == .friends,
                a11yState: scope == .friends ? NSLocalizedString("entry.state.shared", comment: "") : NSLocalizedString("entry.state.onlyYou", comment: ""),
                accent: mood.color
            ) {
                showScopeSheet = true
            }
        }
    }

    private func actionChip(systemImage: String, label: String, filled: Bool, a11yState: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button {
            ONEHaptics.feelingSelected()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .iconSM(weight: .semibold)
                Text(label)
                    .bodyXSSemibold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(filled ? accent.readableInk() : V3Tokens.ink)
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.vertical, V3Tokens.spacingMD)
            .background(
                Capsule(style: .continuous)
                    .fill(filled ? accent : Color.clear)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(filled ? accent : V3Tokens.hairline, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.onePressable)
        .animation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.22), value: filled)
        .accessibilityLabel(String(format: NSLocalizedString("entry.a11y.chip", comment: ""), label, a11yState))
    }

    // MARK: - Footer

    /// v3 spec: tek CTA. "Atla" kaldırıldı — not zaten opsiyonel, Kaydet
    /// boşken de çalışır. İki buton kullanıcıya farklı sonuç bekliyormuş
    /// gibi yanıltıcı geliyordu.
    private var footer: some View {
        Button(action: onSave) {
            Text(NSLocalizedString("entry.save", comment: ""))
                .displayXS()
                .foregroundColor(V3Tokens.paper)
                .frame(maxWidth: .infinity, minHeight: 24)
                .padding(.vertical, V3Tokens.spacingLG)
                .background(Capsule().fill(V3Tokens.ink))
        }
        .buttonStyle(.onePressable)
        .accessibilityLabel(NSLocalizedString("entry.a11y.save", comment: ""))
    }

    // MARK: - Helpers

    /// Ekranda gösterilecek tarih — her zaman bugün. Akış geçmiş bir güne
    /// yazamaz (duruş ilke 3).
    private var dateLabel: String {
        ONEFormatters.dayMonthWeekday.string(from: Date())
    }

    /// VoiceOver için okunabilir (uppercase değil) varyant.
    private var dateLabelSpoken: String {
        dateLabel
    }
}

// MARK: - Photo source sheet (variant with remove for details step)

/// V3StoryComposer'daki source sheet'in yerel kardeşi — bu variant "Kaldır"
/// aksiyonunu da içerir (fotoğraf zaten varsa görünür).
private struct V3DetailsPhotoSourceSheet: View {
    let accent: Color
    let hasPhoto: Bool
    let onGallery: () -> Void
    let onCamera: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            Text(hasPhoto ? NSLocalizedString("entry.photo.change", comment: "") : NSLocalizedString("entry.photo.add", comment: ""))
                .font(V3Typography.display(22, weight: .semibold))
                .tracking(-0.5)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, V3Tokens.spacingXL)

            HStack(spacing: V3Tokens.spacingMD) {
                sourceCard(title: NSLocalizedString("entry.photo.gallery", comment: ""), subtitle: NSLocalizedString("entry.photo.gallerySub", comment: ""),
                           systemImage: "photo.on.rectangle.angled", action: onGallery)
                sourceCard(title: NSLocalizedString("entry.photo.camera", comment: ""), subtitle: NSLocalizedString("entry.photo.cameraSub", comment: ""),
                           systemImage: "camera.fill", action: onCamera)
            }

            if hasPhoto {
                Button(action: onRemove) {
                    HStack(spacing: V3Tokens.spacingSM) {
                        Image(systemName: "trash")
                            .iconSM(weight: .semibold)
                        Text(NSLocalizedString("entry.removePhoto", comment: ""))
                            .bodyMDSemibold()
                    }
                    .foregroundColor(V3Tokens.kor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().stroke(V3Tokens.kor.opacity(0.5), lineWidth: 1.5))
                }
                .buttonStyle(.onePressable)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, V3Tokens.spacingXL)
        .padding(.bottom, V3Tokens.spacingXL)
    }

    private func sourceCard(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            ONEHaptics.feelingSelected()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                        .fill(accent.opacity(0.14))
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(accent)
                }
                .frame(width: 46, height: 46)
                Spacer(minLength: 6)
                Text(title)
                    .bodyLGSemibold()
                    .foregroundColor(V3Tokens.ink)
                Text(subtitle)
                    .bodyMicro()
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(V3Tokens.spacingLG)
            .frame(height: 152)
            .oneCardBackground(radius: V3Tokens.radiusPanel)
        }
        .buttonStyle(.onePressable)
    }
}

// MARK: - Scope sheet

/// "Bu an kimde kalsın?" tam kararlı sheet — iki büyük seçim kartı, mood accent.
private struct V3ScopeSheet: View {
    @Binding var scope: MomentScope
    let moodColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
                Text(NSLocalizedString("entry.scopeTitle", comment: ""))
                    .font(V3Typography.display(22, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundColor(V3Tokens.ink)
                Text(NSLocalizedString("entry.scopeSubtitle", comment: ""))
                    .bodyXS()
                    .foregroundColor(V3Tokens.mutedText)
            }
            .padding(.top, V3Tokens.spacingXL)

            VStack(spacing: V3Tokens.spacingMD) {
                choiceCard(
                    title: NSLocalizedString("entry.scope.privateTitle", comment: ""),
                    subtitle: NSLocalizedString("entry.scope.privateSub", comment: ""),
                    systemImage: "lock.fill",
                    isOn: scope == .private
                ) {
                    scope = .private
                    ONEHaptics.feelingSelected()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { dismiss() }
                }

                choiceCard(
                    title: NSLocalizedString("entry.scope.circleTitle", comment: ""),
                    subtitle: NSLocalizedString("entry.scope.circleSub", comment: ""),
                    systemImage: "person.2.fill",
                    isOn: scope == .friends
                ) {
                    scope = .friends
                    ONEHaptics.feelingSelected()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { dismiss() }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, V3Tokens.spacingXL)
        .padding(.bottom, V3Tokens.spacingXL)
    }

    private func choiceCard(title: String, subtitle: String, systemImage: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                        .fill(isOn ? moodColor : moodColor.opacity(0.14))
                    Image(systemName: systemImage)
                        .iconMD(weight: .semibold)
                        .foregroundColor(isOn ? moodColor.readableInk() : moodColor)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .bodyMDSemibold()
                        .foregroundColor(V3Tokens.ink)
                    Text(subtitle)
                        .bodyMicro()
                        .foregroundColor(V3Tokens.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isOn ? moodColor : V3Tokens.hairline)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                    .fill(V3Tokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                            .stroke(isOn ? moodColor.opacity(0.4) : V3Tokens.hairline, lineWidth: isOn ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.onePressable)
    }
}

// MARK: - Local contrast helper

private extension Color {
    func readableInk() -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luma > 0.62 ? ONEBrand.ink : ONEBrand.bone
    }
}
