//
//  ManagedObjectMapping.swift
//  ONE 2.0
//
//  `…MO` → değer tipi dönüşümleri ve ortak fetch yardımcıları.
//
//  Nesneler entity adıyla oluşturulur (`insertNewObject(forEntityName:)`),
//  `EntryMO(context:)` ile değil: aynı süreçte birden çok model yüklüyken
//  (testler, önizlemeler) sınıf → entity eşlemesi belirsizleşiyor.
//

import CoreData

nonisolated enum ONE2Entity {
    static let entry = "Entry"
    static let answer = "EntryAnswer"
    static let mood = "MoodLog"
    static let day = "DayRecord"
    static let tag = "Tag"
    static let badge = "BadgeAward"
    static let practice = "Practice"
    static let exposure = "ContentExposure"
}

extension NSManagedObjectContext {
    func insert<T: NSManagedObject>(_ entityName: String, as type: T.Type = T.self) -> T {
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: self) as! T
    }

    func fetchAll<T: NSManagedObject>(
        _ entityName: String,
        as type: T.Type = T.self,
        where predicate: NSPredicate? = nil,
        sortedBy sort: [NSSortDescriptor] = []
    ) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sort
        return try fetch(request)
    }

    func fetchOne<T: NSManagedObject>(_ entityName: String, id: UUID, as type: T.Type = T.self) throws -> T? {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try fetch(request).first
    }

    func saveIfNeeded() throws {
        if hasChanges { try save() }
    }
}

extension EntryMO {
    var value: JournalEntry? {
        guard let id, let dayKey, let day = DayKey(dayKey) else { return nil }
        let answers = ((self.answers as? Set<EntryAnswerMO>) ?? [])
            .compactMap(\.value)
            .sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
        return JournalEntry(
            id: id,
            day: day,
            timeZoneID: timeZoneID,
            createdAt: createdAt ?? .distantPast,
            updatedAt: updatedAt ?? createdAt ?? .distantPast,
            kind: kind.flatMap(EntryKind.init(rawValue:)) ?? .freeform,
            title: title,
            body: body,
            wordCount: Int(wordCount),
            contentRef: contentRef,
            contentSnapshot: contentSnapshot,
            isBackfilled: isBackfilled,
            sourceContext: sourceContext.flatMap(EntrySource.init(rawValue:)),
            comparedEntryID: comparedEntryID,
            moodID: mood?.id,
            tagIDs: Set(((tags as? Set<TagMO>) ?? []).compactMap(\.id)),
            answers: answers
        )
    }
}

extension EntryAnswerMO {
    var value: EntryAnswer? {
        guard let id, let kind = kind.flatMap(AnswerKind.init(rawValue:)) else { return nil }
        return EntryAnswer(
            id: id,
            order: Int(order),
            kind: kind,
            stepRef: stepRef,
            questionSnapshot: questionSnapshot,
            text: textValue,
            number: hasNumber ? numberValue : nil,
            bool: hasBool ? boolValue : nil,
            choices: JSONList.decode(choiceValuesJSON),
            metricID: metricID
        )
    }

    func apply(_ answer: EntryAnswer) {
        id = answer.id
        order = Int16(clamping: answer.order)
        kind = answer.kind.rawValue
        stepRef = answer.stepRef
        questionSnapshot = answer.questionSnapshot
        textValue = answer.text
        hasNumber = answer.number != nil
        numberValue = answer.number ?? 0
        hasBool = answer.bool != nil
        boolValue = answer.bool ?? false
        choiceValuesJSON = JSONList.encode(answer.choices)
        metricID = answer.metricID
    }
}

extension MoodLogMO {
    var value: MoodCheckIn? {
        guard let id, let dayKey, let day = DayKey(dayKey) else { return nil }
        return MoodCheckIn(
            id: id,
            day: day,
            timeZoneID: timeZoneID,
            timestamp: timestamp ?? .distantPast,
            score: Int(score),
            emotionIDs: JSONList.decode(emotionIDsJSON),
            causeIDs: JSONList.decode(causeIDsJSON),
            note: note,
            source: source.flatMap(MoodSource.init(rawValue:)) ?? .checkIn,
            healthKitSampleID: healthKitSampleID,
            entryID: entry?.id
        )
    }
}

extension DayRecordMO {
    var completion: DayCompletion? {
        guard let dayKey, let day = DayKey(dayKey) else { return nil }
        return DayCompletion(day: day,
                             dailyCompletedAt: dailyCompletedAt,
                             morningCompletedAt: morningCompletedAt,
                             eveningCompletedAt: eveningCompletedAt)
    }
}

extension TagMO {
    var value: JournalTag? {
        guard let id, let name else { return nil }
        return JournalTag(id: id, name: name, iconName: iconName, createdAt: createdAt ?? .distantPast)
    }
}

extension BadgeAwardMO {
    var value: EarnedBadge? {
        guard let id, let badgeID else { return nil }
        return EarnedBadge(id: id, badgeID: badgeID, earnedAt: earnedAt ?? .distantPast)
    }
}

extension PracticeMO {
    var value: PracticeItem? {
        guard let id, let contentRef else { return nil }
        return PracticeItem(id: id, contentRef: contentRef, order: Int(order), addedAt: addedAt ?? .distantPast)
    }
}
