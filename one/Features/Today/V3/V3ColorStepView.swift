import SwiftUI

/// Adım 1 — Renk seçimi. Uygulamanın tek zorunlu kararı.
struct V3ColorStepView: View {
    @Binding var selectedMood: V3Mood?
    let onContinue: () -> Void

    /// Başlık — container tarafında karar veriliyor:
    ///  • "Bugün nasılsın?" (varsayılan, gün boş)
    ///  • "Bir an daha?" (bugünün ek anı)
    ///  • "12 Temmuz nasıldı?" (geçmiş gün doldururken)
    var title: String = "Bugün\nnasılsın?"
    /// Selam üst satırı (iki tonlu greeting). Nil ise gösterilmez.
    var greeting: String? = nil
    /// "Geçmiş gün" kapsülü — sadece past-day akışında gösterilir.
    var pastDayChip: Bool = false

    /// Container'dan gelen namespace — seçili tile → details hero → doneBlock
    /// arasında `matchedGeometryEffect` ile aynı yüzey taşınır.
    var moodMorph: Namespace.ID? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seçili karenin çift halkası. Halka **karenin içine** çiziliyor —
    /// dışarı taşan bir çerçeve `ScrollView`'ın kırpma sınırında kesiliyordu
    /// (soldaki ve sağdaki sütun). Bkz. `MoodTile`.
    static let selectionRing: CGFloat = 2.5

    var body: some View {
        // Hedef: ekrana tam sığmak. İçerik hâlâ kaydırılabilir — büyük Dynamic
        // Type kademelerinde tek çıkış yolu o — ama varsayılan ayarlarda
        // kaydırma gerekmiyor: ızgara kareleri hafif basık, tipografi payları
        // sıkı. `scrollBounceBehavior(.basedOnSize)` sığdığında zıplamayı da
        // kapatıyor, yani ekran sabit hissediyor.
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                scrollContent
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
    }

    private var scrollContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if pastDayChip {
                Text("GEÇMİŞ GÜN")
                    .font(V3Typography.mono(11, weight: .regular))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(V3Tokens.wash)
                    )
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }

            // Selam varken başlık 38pt'ye iniyor: iki 44pt blok üst üste
            // ızgarayı ekran dışına itiyordu. Selam yokken ("Bir an daha?")
            // yer var, 44pt kalıyor.
            let titleSize: CGFloat = greeting == nil ? 44 : 38

            if let greeting {
                Text(greeting)
                    .font(V3Typography.display(38, weight: .black))
                    .tracking(-1.9)
                    .foregroundColor(V3Tokens.faintText)
                    // Uzun selam ("İyi akşamlar, Abdurrahman") sarılırsa
                    // tipografik kilit iki tonlu tek blok olmaktan çıkıyor —
                    // tek satır kalır, gerekirse küçülür.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, pastDayChip ? 0 : 24)
            }

            Text(title)
                .font(V3Typography.display(titleSize, weight: .black))
                .tracking(titleSize >= 44 ? -2.4 : -1.9)
                .lineSpacing(0)
                .foregroundColor(V3Tokens.ink)
                // Başlık kendi `\n`'ini taşıyor ("Bugün\nnasılsın?") — iki
                // satır tasarım, üçüncüsü taşma.
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.top, greeting == nil && !pastDayChip ? 28 : 2)
                .padding(.bottom, 6)
                .fixedSize(horizontal: false, vertical: true)

            Text("Bir renk seç. Yeter.")
                .font(V3Typography.sans(16, weight: .regular))
                .foregroundColor(V3Tokens.mutedText)
                .padding(.bottom, 18)

            moodGrid
                .padding(.bottom, 4)
        }
    }

    // MARK: - Grid

    private var moodGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 8),
                       GridItem(.flexible(), spacing: 8),
                       GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(V3Mood.allCases) { mood in
                MoodTile(
                    mood: mood,
                    isSelected: selectedMood == mood,
                    reduceMotion: reduceMotion,
                    moodMorph: moodMorph
                ) {
                    ONEHaptics.moodSelected()
                    selectedMood = mood
                }
            }
        }
    }

    // MARK: - Footer

    /// Butonun kendisi **seçilen renk**.
    ///
    /// İki eski denemenin ikisi de yanlıştı: sağa yaslı küçük kapsül + solda
    /// "Henüz seçmedin" satırı dengesizdi; tam genişlik siyah slab ise ekranın
    /// altına ağır bir blok koyuyor, üstündeki degrade "erime" de gölge gibi
    /// okunuyordu. Ekran zaten kaydırılmadığı için o degradenin işlevi de
    /// kalmadı — kaldırıldı.
    ///
    /// Renk bu uygulamada dekorasyon değil, kullanıcının verdiği karar. Karar
    /// verildiğinde eylem o kararın rengini alıyor: seçtiğin renk aşağı iniyor
    /// ve "Devam" oluyor. Metin daima o rengin `ink` çifti — kontrast garanti.
    ///  • Seçim yokken → "Bir renk seç", `wash` zemin + hairline, pasif ama okunur.
    ///  • Seçildiğinde → `mood.color` zemin, `mood.ink` metin.
    private var footer: some View {
        Button(action: { if selectedMood != nil { onContinue() } }) {
            Text(selectedMood == nil ? "Bir renk seç" : "Devam")
                .font(V3Typography.sans(17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundColor(selectedMood?.ink ?? V3Tokens.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(selectedMood?.color ?? V3Tokens.wash)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(V3Tokens.hairline,
                                              lineWidth: selectedMood == nil ? 1 : 0)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(V3CardPressStyle())
        .disabled(selectedMood == nil)
        .accessibilityLabel(selectedMood.map { "Devam, \($0.label) seçildi" } ?? "Bir renk seç")
        .animation(reduceMotion ? nil : V3Tokens.easingColor, value: selectedMood)
        .padding(.top, 14)
        .background(V3Tokens.paper)
    }
}

// MARK: - Mood tile

private struct MoodTile: View {
    let mood: V3Mood
    let isSelected: Bool
    let reduceMotion: Bool
    let moodMorph: Namespace.ID?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    // Morph'a **yalnızca seçili kare** katılır.
                    //
                    // Eskiden dokuz karenin hepsi aynı `id`'yi bildiriyordu ve
                    // seçili olmayanlar `isSource: false` ile kaynağın
                    // geometrisini **benimsiyordu**: sekiz kare kendi
                    // hücresini bırakıp seçili karenin üstüne yığılıyor,
                    // renkleri ve etiketleri üst üste biniyordu. ("Yorgun'un
                    // rengi seçtiğim rengin üzerine geliyor.")
                    //
                    // Hedef (details hero) tek kaynak bekler; seçili olmayan
                    // karelerin bu kimlikle hiç ilişkisi olmamalı.
                    if let ns = moodMorph, isSelected {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(mood.color)
                            .matchedGeometryEffect(id: "moodSurface", in: ns, isSource: true)
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(mood.color)
                    }
                }
                // Kareler artık tam kare değil, hafif basık (1 : 0.88).
                // Üç sıra 3×3 ızgarayı ekrana sığdırmak için ~36pt kazandırıyor
                // ve kullanıcı kaydırmak zorunda kalmıyor.
                .aspectRatio(1.0 / 0.88, contentMode: .fit)

                Text(mood.label.lowercased())
                    .font(V3Typography.sans(14, weight: .semibold))
                    .foregroundColor(mood.ink)
                    .padding(11)
            }
            .scaleEffect(isSelected && !reduceMotion ? 1.02 : 1.0)
            // Çift halka **içeri** çiziliyor.
            //
            // Eskiden dış halka `padding(-3)` ile karenin dışına taşıyordu.
            // Izgaranın en solundaki ve en sağındaki sütunda bu taşma
            // `ScrollView`'ın kırpma sınırına denk geliyor ve halkanın o kenarı
            // yarıda kesiliyordu ("ateşli'yi seçince sol çizgi kesiliyor").
            // `strokeBorder` şeklin içine çizer — hiçbir kenar taşmaz.
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(V3Tokens.ink,
                                  lineWidth: isSelected ? V3ColorStepView.selectionRing : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24 - V3ColorStepView.selectionRing, style: .continuous)
                    .strokeBorder(V3Tokens.paper,
                                  lineWidth: isSelected ? V3ColorStepView.selectionRing : 0)
                    .padding(V3ColorStepView.selectionRing)
            )
            .animation(reduceMotion ? nil : V3Tokens.easingPress, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityValue(mood.bridgedMood.meaning)
        .accessibilityHint("Bugünün rengi olarak seç")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
