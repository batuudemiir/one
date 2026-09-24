//
//  MomentDeduplicator.swift
//  one
//
//  CloudKit çoklu-cihaz uzlaştırması.
//
//  `NSPersistentCloudKitContainer` uniqueness constraint desteklemiyor —
//  model katmanında çakışmayı önlemek mümkün değil, sync sonrası uzlaştırmak
//  zorundayız. İki ayrı bozulma var:
//
//  1. **Çift pas-işareti.** `savePassedDay` oku-sonra-yaz yapıyor; iki cihaz
//     da "bu gün boş" görüp pas kaydı ekleyebiliyor. Bunlar anlamsız çift
//     satır ve arşiv/özet sayımlarını şişiriyor. Ayrıca gerçek bir an sonradan
//     sync olursa "gerçek giriş varsa pası geçersiz kıl" kuralı bozuluyor.
//
//  2. **entryIndex çakışması.** `nextEntryIndex` max+1 veriyor; iki cihaz aynı
//     gün an eklerse ikisi de aynı indeksi üretiyor. Bu anlar *gerçek* ve ikisi
//     de kalmalı — ama `CloudKitDailyShareService` entryIndex'i paylaşım
//     kaydının kimliği olarak kullandığı için çakışma bir anın paylaşımının
//     diğerini ezmesine yol açıyor.
//
//  Uzlaştırma **deterministik** olmak zorunda: her cihaz aynı senkron veri
//  kümesinden aynı sonucu üretmeli, yoksa düzeltmeler birbirini kovalar.
//  Sıralama anahtarı `(createdAt, id.uuidString)` — ikisi de senkronize alan,
//  ikisi de her cihazda aynı.
//

import CoreData
import Foundation

enum MomentDeduplicator {

    /// Uzlaştırma sonucunda ne değiştiğini çağırana bildirir.
    struct Result {
        var removedPassMarkers = 0
        var reindexedMoments = 0

        var didChange: Bool { removedPassMarkers > 0 || reindexedMoments > 0 }
    }

    /// Verilen context'te tüm günleri tarar ve iki bozulmayı da düzeltir.
    ///
    /// Çağıran `context.save()` sorumlu değil — bu fonksiyon değişiklik varsa
    /// kendisi kaydeder, çünkü kısmen uzlaştırılmış bir durum bırakmak
    /// bir sonraki turda farklı sonuç üretir.
    @discardableResult
    static func reconcile(in context: NSManagedObjectContext) -> Result {
        var result = Result()

        let request: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        // Tüm kayıtları tek seferde belleğe almadan gez.
        request.fetchBatchSize = 200

        let all: [DailySong]
        do {
            all = try context.fetch(request)
        } catch {
            ONELogger.error("Dedupe fetch başarısız: \(error.localizedDescription)", category: .persistence)
            return result
        }

        // Güne göre grupla. `date` normalize edilmiş (startOfDay) olarak
        // yazılıyor, yani doğrudan anahtar olarak kullanılabilir.
        var byDay: [Date: [DailySong]] = [:]
        for song in all {
            guard let day = song.date else { continue }
            byDay[day, default: []].append(song)
        }

        for (_, group) in byDay {
            result.removedPassMarkers += resolvePassMarkers(in: group, context: context)
            result.reindexedMoments += resolveEntryIndexes(in: group, context: context)
        }

        guard result.didChange else { return result }

        do {
            try context.save()
            ONELogger.debug(
                "Dedupe: \(result.removedPassMarkers) pas işareti silindi, \(result.reindexedMoments) an yeniden indekslendi",
                category: .persistence
            )
        } catch {
            ONELogger.error("Dedupe kaydedilemedi: \(error.localizedDescription)", category: .persistence)
            context.rollback()
            return Result()
        }

        return result
    }

    // MARK: - 1. Pas işaretleri

    /// Bir güne ait pas işaretlerini tekilleştirir.
    ///
    /// Kural: o günde gerçek bir an varsa pas işaretlerinin **hepsi** gider
    /// (`savePassedDay`'in korumaya çalıştığı ama yarışta kaybettiği kural).
    /// Gerçek an yoksa en eski pas işareti kalır, kalanlar gider.
    private static func resolvePassMarkers(
        in group: [DailySong],
        context: NSManagedObjectContext
    ) -> Int {
        let passMarkers = group.filter { $0.passed }
        guard passMarkers.count > 0 else { return 0 }

        let realMoments = group.filter { !$0.passed }

        let doomed: [DailySong]
        if realMoments.isEmpty {
            // Hepsi pas — en eskisini tut.
            guard passMarkers.count > 1 else { return 0 }
            doomed = Array(sortedDeterministically(passMarkers).dropFirst())
        } else {
            // Gerçek an var — pas işaretinin hiçbiri geçerli değil.
            doomed = passMarkers
        }

        for marker in doomed { context.delete(marker) }
        return doomed.count
    }

    // MARK: - 2. entryIndex çakışması

    /// Bir güne ait anların `entryIndex`'lerini 0..<n olacak şekilde
    /// deterministik sırayla yeniden atar.
    ///
    /// Yalnızca gerçekten bozuk olan günlere dokunur (çakışma ya da boşluk),
    /// çünkü her uzlaştırmada her satırı yazmak CloudKit'e gereksiz trafik
    /// bindirir ve sonsuz sync döngüsü riski yaratır.
    private static func resolveEntryIndexes(
        in group: [DailySong],
        context: NSManagedObjectContext
    ) -> Int {
        let moments = group.filter { !$0.passed }
        guard moments.count > 1 else { return 0 }

        let ordered = sortedDeterministically(moments)
        let current = ordered.map(\.entryIndex)
        let expected = Array(0..<Int16(ordered.count))

        // Zaten 0..<n ve doğru sırada mı? Öyleyse dokunma.
        guard current != expected else { return 0 }

        var changed = 0
        for (offset, moment) in ordered.enumerated() {
            let target = Int16(offset)
            if moment.entryIndex != target {
                moment.entryIndex = target
                changed += 1
            }
        }
        return changed
    }

    // MARK: - Deterministik sıralama

    /// Her cihazda aynı sonucu veren sıralama.
    ///
    /// `createdAt` birincil anahtar; aynı milisaniyede oluşmuş iki kayıt için
    /// `id` string'i tie-break. İkisi de CloudKit üzerinden senkronize olduğu
    /// için her cihaz aynı diziyi üretir.
    private static func sortedDeterministically(_ songs: [DailySong]) -> [DailySong] {
        songs.sorted { lhs, rhs in
            let l = lhs.createdAt ?? .distantPast
            let r = rhs.createdAt ?? .distantPast
            if l != r { return l < r }
            return (lhs.id?.uuidString ?? "") < (rhs.id?.uuidString ?? "")
        }
    }
}
