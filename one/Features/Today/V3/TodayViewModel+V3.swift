import SwiftUI
import CoreData

extension TodayViewModel {

    /// v3 kayıt yolu — şarkılı ya da şarkısız, bugüne ya da geçmiş bir güne.
    ///
    /// Eskiden burada `if let song` diye bir dallanma vardı ve şarkılı kayıt
    /// legacy `saveEntry`'ye gidiyordu. O yol iki şeyi sessizce bozuyordu:
    ///
    /// 1. **Upsert.** `saveEntry` günün tek kaydını günceller. v3'ün çekirdek
    ///    vaadi "bir gün = N an" olduğu hâlde, şarkı seçen kullanıcı o günün
    ///    önceki anlarını eziyordu.

    /// Artık tek yol var: `MomentWriter`. Aynı yolu App Intents (Siri /
    /// kısayol / Control Center) de kullanıyor — uygulamadan kaydetmekle
    /// Siri'den kaydetmek arasında fark kalmıyor.
    @MainActor
    func saveV3Entry(
        mood: V3Mood,
        note: String,
        photo: UIImage?,
        song: SongResult?,
        scope: MomentScope = .private
    ) {
        guard MomentWriter.write(
            mood: mood,
            note: note,
            photo: photo,
            song: song,
            scope: scope,
            context: self.context
        ) else { return }

        // vm'nin published state'ini yenile — bir sonraki render'da Kaydedildi
        // ekranı ve son 7 gün şeridi doğru veriyle gelir.
        reloadAfterV3Save()
    }
}
