import SwiftUI

struct KesfetMood: Identifiable {
    let id: String
    let label: String
    let color: Color
    let textOnDark: Bool
}

let KESFET_MOODS: [KesfetMood] = [
    KesfetMood(id: "tutkulu",   label: "TUTKULU",    color: Color(hex: "#E94837"), textOnDark: false),
    KesfetMood(id: "mutlu",     label: "MUTLU",      color: Color(hex: "#F3CE38"), textOnDark: true),
    KesfetMood(id: "enerjik",   label: "ENERJİK",    color: Color(hex: "#F39236"), textOnDark: false),
    KesfetMood(id: "dogal",     label: "DOĞAL",      color: Color(hex: "#86C95F"), textOnDark: true),
    KesfetMood(id: "huzurlu",   label: "HUZURLU",    color: Color(hex: "#3CA47D"), textOnDark: false),
    KesfetMood(id: "heyecanli", label: "HEYECANLİ",  color: Color(hex: "#3CB2C5"), textOnDark: false),
    KesfetMood(id: "sakin",     label: "SAKİN",      color: Color(hex: "#3C7FE0"), textOnDark: false),
    KesfetMood(id: "stabil",    label: "STABİL",     color: Color(hex: "#4848C3"), textOnDark: false),
    KesfetMood(id: "uzgun",     label: "ÜZGÜN",      color: Color(hex: "#9F8FE6"), textOnDark: false),
    KesfetMood(id: "stresli",   label: "STRESLİ",    color: Color(hex: "#E89AC6"), textOnDark: true),
    KesfetMood(id: "yorgun",    label: "YORGUN",     color: Color(hex: "#B5B1A8"), textOnDark: true),
    KesfetMood(id: "sinirli",   label: "SİNİRLİ",   color: Color(hex: "#1C1C1F"), textOnDark: false),
]

struct KesfetSong: Identifiable {
    let id: String
    let title: String
    let artist: String
    let mono: String
    let gradientColors: [Color]
}

let KESFET_SONGS: [KesfetSong] = [
    KesfetSong(id: "beni-al",    title: "Beni Al",                        artist: "Ankara Echoes",              mono: "AE", gradientColors: [Color(hex:"#F39236"), Color(hex:"#E94837"), Color(hex:"#4848C3")]),
    KesfetSong(id: "metro",      title: "Metro",                          artist: "Kevin de Vries & Mau P",     mono: "KM", gradientColors: [Color(hex:"#1C1C1F"), Color(hex:"#3C7FE0")]),
    KesfetSong(id: "her-nere",   title: "Her Nerdeysen",                  artist: "Ati242",                     mono: "A2", gradientColors: [Color(hex:"#3CA47D"), Color(hex:"#1C1C1F")]),
    KesfetSong(id: "7seconds",   title: "7 Seconds",                      artist: "Joezi",                      mono: "JZ", gradientColors: [Color(hex:"#F3CE38"), Color(hex:"#E94837")]),
    KesfetSong(id: "trance",     title: "Trance",                         artist: "Metro Boomin, Travis Scott", mono: "MB", gradientColors: [Color(hex:"#1C1C1F"), Color(hex:"#4848C3")]),
    KesfetSong(id: "ask-kir",    title: "Aşk Kırıntıları",                artist: "Teoman",                     mono: "TM", gradientColors: [Color(hex:"#9F8FE6"), Color(hex:"#E89AC6")]),
    KesfetSong(id: "return-oz",  title: "Return to Oz (ARTBAT Remix)",    artist: "Monolink",                   mono: "ML", gradientColors: [Color(hex:"#3CB2C5"), Color(hex:"#3C7FE0"), Color(hex:"#4848C3")]),
    KesfetSong(id: "sana-ait",   title: "Sana Ait",                       artist: "Madrigal",                   mono: "MG", gradientColors: [Color(hex:"#E94837"), Color(hex:"#1C1C1F")]),
    KesfetSong(id: "gel-yanima", title: "Gel Yanıma",                     artist: "Mabel Matiz",                mono: "MM", gradientColors: [Color(hex:"#E89AC6"), Color(hex:"#9F8FE6"), Color(hex:"#4848C3")]),
    KesfetSong(id: "kucuk-kiz",  title: "Küçük Kız",                      artist: "Crystal Castles",            mono: "CC", gradientColors: [Color(hex:"#1C1C1F"), Color(hex:"#3CB2C5")]),
    KesfetSong(id: "gece-yari",  title: "Gece Yarısı",                    artist: "Adamlar",                    mono: "AD", gradientColors: [Color(hex:"#4848C3"), Color(hex:"#1C1C1F")]),
    KesfetSong(id: "mavi-saat",  title: "Mavi Saat",                      artist: "Cem Adrian",                 mono: "CA", gradientColors: [Color(hex:"#3C7FE0"), Color(hex:"#9F8FE6")]),
]

struct KesfetVenue: Identifiable {
    let id: String
    let name: String
    let kind: String
    let neighborhood: String
    let distance: String
    let time: String
    let gradientColors: [Color]
    let moodId: String
    let poster: String
}

let VENUES_TONIGHT: [KesfetVenue] = [
    KesfetVenue(id: "babylon",  name: "Babylon",       kind: "Konser",     neighborhood: "Beyoğlu",      distance: "1.2 km", time: "21:00", gradientColors: [Color(hex:"#1C1C1F"), Color(hex:"#3CA47D")], moodId: "huzurlu",   poster: "AE"),
    KesfetVenue(id: "salon",    name: "Salon İKSV",    kind: "Akustik",    neighborhood: "Şişhane",      distance: "2.4 km", time: "20:30", gradientColors: [Color(hex:"#9F8FE6"), Color(hex:"#4848C3")], moodId: "uzgun",     poster: "CA"),
    KesfetVenue(id: "iksv2",    name: "IF Beşiktaş",   kind: "Caz",        neighborhood: "Beşiktaş",     distance: "3.1 km", time: "22:00", gradientColors: [Color(hex:"#3C7FE0"), Color(hex:"#1C1C1F")], moodId: "sakin",     poster: "NC"),
    KesfetVenue(id: "kakao",    name: "Kakao",          kind: "DJ Set",     neighborhood: "Karaköy",      distance: "0.9 km", time: "00:00", gradientColors: [Color(hex:"#E94837"), Color(hex:"#1C1C1F")], moodId: "tutkulu",   poster: "XR"),
    KesfetVenue(id: "minimuz",  name: "Minimüzikhol",  kind: "Sahne",      neighborhood: "Cihangir",     distance: "0.6 km", time: "21:30", gradientColors: [Color(hex:"#3CB2C5"), Color(hex:"#3CA47D")], moodId: "heyecanli", poster: "AT"),
    KesfetVenue(id: "zorlu",    name: "Zorlu PSM",      kind: "Performans", neighborhood: "Zincirlikuyu", distance: "6.4 km", time: "20:00", gradientColors: [Color(hex:"#F39236"), Color(hex:"#E94837")], moodId: "enerjik",   poster: "PS"),
    KesfetVenue(id: "pera",     name: "Pera Müzesi",    kind: "Sinema",     neighborhood: "Tepebaşı",     distance: "1.4 km", time: "19:00", gradientColors: [Color(hex:"#B5B1A8"), Color(hex:"#1C1C1F")], moodId: "yorgun",    poster: "WW"),
    KesfetVenue(id: "bostanci", name: "Bostancı GM",    kind: "Konser",     neighborhood: "Kadıköy",      distance: "8.2 km", time: "21:00", gradientColors: [Color(hex:"#F3CE38"), Color(hex:"#F39236")], moodId: "mutlu",     poster: "Y4"),
    KesfetVenue(id: "peyote",   name: "Peyote",         kind: "Gece",       neighborhood: "Beyoğlu",      distance: "1.0 km", time: "23:30", gradientColors: [Color(hex:"#1C1C1F"), Color(hex:"#3a0c08")], moodId: "sinirli",   poster: "NW"),
    KesfetVenue(id: "kuf",      name: "KÜF Sahnesi",   kind: "Çıkış",      neighborhood: "Kadıköy",      distance: "5.8 km", time: "20:30", gradientColors: [Color(hex:"#86C95F"), Color(hex:"#3CA47D")], moodId: "dogal",     poster: "MG"),
    KesfetVenue(id: "hocap",    name: "Hodjapasha",     kind: "Ritüel",     neighborhood: "Sirkeci",      distance: "3.0 km", time: "19:30", gradientColors: [Color(hex:"#4848C3"), Color(hex:"#9F8FE6")], moodId: "stabil",    poster: "HP"),
    KesfetVenue(id: "karsi",    name: "Salon Karşı",   kind: "Okuma",      neighborhood: "Karaköy",      distance: "1.6 km", time: "20:00", gradientColors: [Color(hex:"#E89AC6"), Color(hex:"#9F8FE6")], moodId: "stresli",   poster: "PŞ"),
]

struct KesfetCollection: Identifiable {
    let id: String
    let name: String
    let count: Int
    let gradientColors: [Color]
}

let KESFET_COLLECTIONS: [KesfetCollection] = [
    KesfetCollection(id: "gece",    name: "Gece Açanlar",     count: 18, gradientColors: [Color(hex:"#1C1C1F"), Color(hex:"#4848C3")]),
    KesfetCollection(id: "sabah",   name: "Sabah Sessizliği", count: 12, gradientColors: [Color(hex:"#3CA47D"), Color(hex:"#86C95F")]),
    KesfetCollection(id: "pencere", name: "Pencere Önü",      count:  9, gradientColors: [Color(hex:"#3C7FE0"), Color(hex:"#3CB2C5")]),
    KesfetCollection(id: "yagmur",  name: "Yağmurda",         count: 14, gradientColors: [Color(hex:"#4848C3"), Color(hex:"#9F8FE6")]),
    KesfetCollection(id: "cuma",    name: "Cuma Akşamı",      count: 23, gradientColors: [Color(hex:"#E94837"), Color(hex:"#F39236")]),
    KesfetCollection(id: "tek",     name: "Tek Başına",       count:  7, gradientColors: [Color(hex:"#E89AC6"), Color(hex:"#9F8FE6")]),
]

struct KesfetWeekEvent: Identifiable {
    let id = UUID()
    let day: String
    let date: String
    let title: String
    let venue: String
    let moodId: String
    let time: String
}

let KESFET_WEEK_EVENTS: [KesfetWeekEvent] = [
    KesfetWeekEvent(day: "Pe", date: "14", title: "Sıla",              venue: "Volkswagen Arena", moodId: "uzgun",   time: "21:00"),
    KesfetWeekEvent(day: "Cu", date: "15", title: "Pinhani",           venue: "Bostancı GM",      moodId: "huzurlu", time: "20:30"),
    KesfetWeekEvent(day: "Ct", date: "16", title: "Adamlar",           venue: "Salon İKSV",       moodId: "tutkulu", time: "21:00"),
    KesfetWeekEvent(day: "Pz", date: "17", title: "Cem Adrian — Solo", venue: "Zorlu PSM",        moodId: "sakin",   time: "20:00"),
]

struct FeaturedCuration {
    let title: String
    let sub: String
    let tag: String
    let time: String
    let distance: String
    let going: Int
    let why: String
}

struct ArtistCuration {
    let name: String
    let date: String
    let venue: String
    let intent: String
    let mono: String
    let gradientColors: [Color]
}

struct MoodCuration {
    let quality: String
    let line: String
    let invite: String
    let featured: FeaturedCuration
    let artist: ArtistCuration
    let songIds: [String]
    let venueIds: [String]
    let collectionIds: [String]
    let weekIdx: Int
}

private func _buildMoodCuration() -> [String: MoodCuration] {
    var d = [String: MoodCuration]()
    d["tutkulu"] = MoodCuration(
        quality: "kavurucu", line: "Şehir alev alev. Sen ortasındasın.", invite: "şehri yakmaya hazır",
        featured: FeaturedCuration(title: "Tehlikeli Geçit", sub: "Kakao · Karaköy", tag: "GECE SAHNESİ", time: "Cuma · 23:00", distance: "0.9 km", going: 312, why: "Bu his için kalbi hızlı atan bir gece set."),
        artist: ArtistCuration(name: "Adamlar", date: "16 Mart", venue: "Salon İKSV", intent: "CUMARTESİ ŞEHRİNDE", mono: "AD", gradientColors: [Color(hex: "#E94837"), Color(hex: "#7a1f15"), Color(hex: "#1C1C1F")]),
        songIds: ["metro","trance","7seconds","gece-yari","sana-ait","return-oz","kucuk-kiz","ask-kir"],
        venueIds: ["kakao","peyote","minimuz","iksv2","salon","babylon"],
        collectionIds: ["cuma","gece","tek","yagmur","pencere","sabah"],
        weekIdx: 2)
    d["mutlu"] = MoodCuration(
        quality: "ışıltılı", line: "Göz kırpan camlar. Bir balkonda biri gülüyor.", invite: "gülerek geçecek",
        featured: FeaturedCuration(title: "Açık Sahne: İlk Yaz", sub: "Maçka Demokrasi Parkı", tag: "AÇIK HAVA", time: "Pazar · 17:00", distance: "2.0 km", going: 487, why: "Güneş hâlâ yukarıda — buluşmak, dans etmek, gülmek için."),
        artist: ArtistCuration(name: "Yüzyüzeyken Konuşuruz", date: "29 Mart", venue: "Zorlu PSM", intent: "AY SONU", mono: "YK", gradientColors: [Color(hex: "#F3CE38"), Color(hex: "#F39236"), Color(hex: "#E94837")]),
        songIds: ["gel-yanima","sana-ait","beni-al","her-nere","mavi-saat","7seconds","return-oz","metro"],
        venueIds: ["bostanci","zorlu","babylon","minimuz","salon","iksv2"],
        collectionIds: ["cuma","pencere","sabah","gece","tek","yagmur"],
        weekIdx: 1)
    d["enerjik"] = MoodCuration(
        quality: "kıpırdak", line: "Kapıdan çıkmak için bir bahane daha.", invite: "dışarı çıkmak için",
        featured: FeaturedCuration(title: "Marmaray Sound", sub: "Festival · Maslak", tag: "FESTİVAL", time: "Cumartesi · 19:00", distance: "4.1 km", going: 1240, why: "Üç sahne, gece boyu — bu enerjinin ihtiyacı."),
        artist: ArtistCuration(name: "Athena", date: "22 Mart", venue: "Volkswagen Arena", intent: "HAFTA SONU", mono: "AT", gradientColors: [Color(hex: "#F39236"), Color(hex: "#E94837"), Color(hex: "#4848C3")]),
        songIds: ["metro","return-oz","trance","7seconds","beni-al","gece-yari","sana-ait","gel-yanima"],
        venueIds: ["zorlu","kakao","babylon","minimuz","peyote","iksv2"],
        collectionIds: ["cuma","gece","yagmur","tek","pencere","sabah"],
        weekIdx: 2)
    d["dogal"] = MoodCuration(
        quality: "yeşeren", line: "İlk nefes — yeniden bir şeyler.", invite: "tazelenecek",
        featured: FeaturedCuration(title: "Yeniden — Yeni Albüm Lansmanı", sub: "KÜF Sahnesi", tag: "ÇIKIŞ", time: "Cumartesi · 20:30", distance: "5.8 km", going: 220, why: "Yeni çıkan bir albüm, yeni başlayan bir şey için."),
        artist: ArtistCuration(name: "Madrigal", date: "14 Mart", venue: "Beyrut Performance", intent: "BU HAFTA", mono: "MG", gradientColors: [Color(hex: "#86C95F"), Color(hex: "#3CA47D"), Color(hex: "#1C1C1F")]),
        songIds: ["her-nere","beni-al","mavi-saat","gel-yanima","sana-ait","ask-kir","return-oz","metro"],
        venueIds: ["kuf","minimuz","salon","iksv2","babylon","zorlu"],
        collectionIds: ["sabah","pencere","tek","yagmur","cuma","gece"],
        weekIdx: 0)
    d["huzurlu"] = MoodCuration(
        quality: "yumuşak", line: "Akşam yumuşuyor. Ses kısılıyor.", invite: "yavaş bir akşam için",
        featured: FeaturedCuration(title: "7 Pink Floyd'lar ve 2 Prenses", sub: "Babylon", tag: "SANATÇI KONSERİ", time: "Çarşamba · 21:00", distance: "1.2 km", going: 219, why: "Yumuşak bir akşamı kucaklayan akustik bir setlist."),
        artist: ArtistCuration(name: "Mabel Matiz", date: "27 Mart", venue: "Volkswagen Arena", intent: "YAKINDA ŞEHRİNDE", mono: "MM", gradientColors: [Color(hex: "#9F8FE6"), Color(hex: "#4848C3"), Color(hex: "#1C1C1F")]),
        songIds: ["ask-kir","mavi-saat","beni-al","her-nere","sana-ait","gel-yanima","return-oz","gece-yari"],
        venueIds: ["babylon","salon","minimuz","iksv2","kuf","zorlu"],
        collectionIds: ["pencere","sabah","yagmur","tek","gece","cuma"],
        weekIdx: 1)
    d["heyecanli"] = MoodCuration(
        quality: "akıcı", line: "Kapılar aralık. Sen seçiyorsun.", invite: "sınır tanımayan",
        featured: FeaturedCuration(title: "Sokakta Caz Akşamı", sub: "Karaköy Açık Sahne", tag: "BULUŞMA", time: "Cuma · 18:00", distance: "0.7 km", going: 96, why: "Yürüyerek geçtiğin sokak bu akşam sahne olacak."),
        artist: ArtistCuration(name: "Pinhani", date: "15 Mart", venue: "Bostancı Gösteri Merkezi", intent: "CUMARTESİ", mono: "PI", gradientColors: [Color(hex: "#3CB2C5"), Color(hex: "#3CA47D"), Color(hex: "#1C1C1F")]),
        songIds: ["gel-yanima","return-oz","her-nere","beni-al","sana-ait","metro","mavi-saat","trance"],
        venueIds: ["minimuz","kakao","salon","babylon","iksv2","zorlu"],
        collectionIds: ["cuma","tek","pencere","gece","sabah","yagmur"],
        weekIdx: 2)
    d["sakin"] = MoodCuration(
        quality: "durgun", line: "Su kıpırdamıyor. Sen dinliyorsun.", invite: "iç sesini dinleten",
        featured: FeaturedCuration(title: "Cem Adrian — Solo Akustik", sub: "Zorlu PSM", tag: "SAHNE", time: "Pazar · 20:00", distance: "6.4 km", going: 540, why: "Tek bir adam, tek bir gitar — saat duruyor."),
        artist: ArtistCuration(name: "Cem Adrian", date: "17 Mart", venue: "Zorlu PSM", intent: "PAZAR AKŞAMI", mono: "CA", gradientColors: [Color(hex: "#3C7FE0"), Color(hex: "#1C1C1F")]),
        songIds: ["mavi-saat","ask-kir","her-nere","beni-al","sana-ait","gece-yari","gel-yanima","return-oz"],
        venueIds: ["iksv2","zorlu","salon","babylon","minimuz","hocap"],
        collectionIds: ["pencere","sabah","yagmur","tek","gece","cuma"],
        weekIdx: 3)
    d["stabil"] = MoodCuration(
        quality: "sabit", line: "Yer dar değil. Acelen de yok.", invite: "aceleye gelmeyecek",
        featured: FeaturedCuration(title: "Hocapaşa Mevlevileri — Sema Ayini", sub: "Hodjapasha Dance Theater", tag: "RİTÜEL", time: "Cumartesi · 19:30", distance: "3.0 km", going: 145, why: "Aynı ritim, aynı yer — sen sadece bakıyorsun."),
        artist: ArtistCuration(name: "Nilüfer Yanya", date: "5 Nisan", venue: "Babylon", intent: "NİSAN BAŞINDA", mono: "NY", gradientColors: [Color(hex: "#4848C3"), Color(hex: "#1C1C1F")]),
        songIds: ["her-nere","beni-al","mavi-saat","ask-kir","gel-yanima","sana-ait","return-oz","gece-yari"],
        venueIds: ["hocap","salon","iksv2","babylon","zorlu","minimuz"],
        collectionIds: ["tek","sabah","pencere","yagmur","gece","cuma"],
        weekIdx: 1)
    d["uzgun"] = MoodCuration(
        quality: "duraklayan", line: "Eski bir parça çalıyor — uzak bir köşede.", invite: "kalbe iyi gelecek",
        featured: FeaturedCuration(title: "Sıla", sub: "Volkswagen Arena", tag: "KONSER", time: "Perşembe · 21:00", distance: "4.8 km", going: 1800, why: "Bu hisle gidilecek yer — bilenler bilir."),
        artist: ArtistCuration(name: "Sıla", date: "14 Mart", venue: "Volkswagen Arena", intent: "BU PERŞEMBE", mono: "SI", gradientColors: [Color(hex: "#9F8FE6"), Color(hex: "#4848C3"), Color(hex: "#1C1C1F")]),
        songIds: ["ask-kir","mavi-saat","her-nere","gece-yari","beni-al","sana-ait","gel-yanima","return-oz"],
        venueIds: ["salon","iksv2","zorlu","babylon","minimuz","pera"],
        collectionIds: ["yagmur","pencere","tek","gece","sabah","cuma"],
        weekIdx: 0)
    d["stresli"] = MoodCuration(
        quality: "gergin", line: "Kalp bir cam ince. Yumuşatmak gerek.", invite: "nefes aldıracak",
        featured: FeaturedCuration(title: "Sub Soul Listening Session", sub: "Minimüzikhol", tag: "LİSTENİNG", time: "Cumartesi · 22:00", distance: "0.6 km", going: 64, why: "Konuşmadan oturulan bir akşam — gerekiyor."),
        artist: ArtistCuration(name: "Büyük Ev Ablukada", date: "24 Mart", venue: "IF Beşiktaş", intent: "BU AY İÇİNDE", mono: "BA", gradientColors: [Color(hex: "#E89AC6"), Color(hex: "#9F8FE6"), Color(hex: "#4848C3")]),
        songIds: ["mavi-saat","ask-kir","her-nere","beni-al","gel-yanima","sana-ait","gece-yari","return-oz"],
        venueIds: ["minimuz","karsi","salon","babylon","iksv2","pera"],
        collectionIds: ["pencere","sabah","yagmur","tek","gece","cuma"],
        weekIdx: 1)
    d["yorgun"] = MoodCuration(
        quality: "tükenmiş", line: "Kelimeler azaldı. Yakın, az, sade.", invite: "az enerjiyle gidilebilecek",
        featured: FeaturedCuration(title: "Sessiz Sinema · Wim Wenders", sub: "Pera Müzesi", tag: "GÖSTERİM", time: "Cuma · 19:00", distance: "1.4 km", going: 110, why: "Konuşmadan, koltuğa yaslanıp."),
        artist: ArtistCuration(name: "Olivia Belli", date: "12 Nisan", venue: "Cemal Reşit Rey", intent: "NİSAN", mono: "OB", gradientColors: [Color(hex: "#B5B1A8"), Color(hex: "#8E867C"), Color(hex: "#1C1C1F")]),
        songIds: ["mavi-saat","ask-kir","beni-al","her-nere","gel-yanima","gece-yari","sana-ait","return-oz"],
        venueIds: ["pera","minimuz","salon","iksv2","babylon","karsi"],
        collectionIds: ["pencere","sabah","tek","yagmur","gece","cuma"],
        weekIdx: 1)
    d["sinirli"] = MoodCuration(
        quality: "taşkın", line: "Sıkışmış bir bas. Bırakacak yer arıyor.", invite: "yumruğunu açtıracak",
        featured: FeaturedCuration(title: "No Wave · Underground Night", sub: "Peyote", tag: "GECE SAHNESİ", time: "Cuma · 23:30", distance: "1.0 km", going: 280, why: "Dışarı çıkması gereken bir şey var."),
        artist: ArtistCuration(name: "Nilüfer Yanya", date: "5 Nisan", venue: "Babylon", intent: "NİSAN BAŞINDA", mono: "NY", gradientColors: [Color(hex: "#1C1C1F"), Color(hex: "#3a0c08"), Color(hex: "#E94837")]),
        songIds: ["trance","metro","gece-yari","7seconds","return-oz","kucuk-kiz","sana-ait","beni-al"],
        venueIds: ["peyote","kakao","iksv2","minimuz","babylon","salon"],
        collectionIds: ["gece","cuma","yagmur","tek","sabah","pencere"],
        weekIdx: 2)
    return d
}
let MOOD_CURATION = _buildMoodCuration()

private let _fallbackCuration = MoodCuration(
    quality: "yumuşak", line: "Akşam yumuşuyor.", invite: "yavaş bir akşam için",
    featured: FeaturedCuration(title: "—", sub: "—", tag: "—", time: "—", distance: "—", going: 0, why: "—"),
    artist: ArtistCuration(name: "—", date: "—", venue: "—", intent: "—", mono: "—", gradientColors: [Color(hex: "#1C1C1F")]),
    songIds: [], venueIds: [], collectionIds: [], weekIdx: 0
)

private let _fallbackMood = KesfetMood(id: "huzurlu", label: "HUZURLU", color: Color(hex: "#3CA47D"), textOnDark: false)

func curationFor(_ moodId: String) -> MoodCuration {
    MOOD_CURATION[moodId] ?? MOOD_CURATION["huzurlu"] ?? _fallbackCuration
}

func moodFor(_ id: String) -> KesfetMood {
    KESFET_MOODS.first { $0.id == id } ?? KESFET_MOODS.first { $0.id == "huzurlu" } ?? _fallbackMood
}

func kesfetMoodId(from canonicalLabel: String) -> String {
    switch canonicalLabel.lowercased() {
    case "ateşli", "tutkulu": return "tutkulu"
    case "coşkulu", "enerjik": return "enerjik"
    case "mutlu": return "mutlu"
    case "doğal": return "dogal"
    case "huzurlu": return "huzurlu"
    case "özgür", "heyecanli", "heyecanlı": return "heyecanli"
    case "derin", "stabil": return "stabil"
    case "nostaljik", "uzgun", "üzgün": return "uzgun"
    case "gizemli", "sinirli", "siniril", "sinirli̇": return "sinirli"
    case "hassas", "stresli": return "stresli"
    case "sessiz", "yorgun": return "yorgun"
    case "sakin": return "sakin"
    default: return "huzurlu"
    }
}

func canonicalMoodLabel(from kesfetId: String) -> String {
    switch kesfetId {
    case "tutkulu": return "Ateşli"
    case "enerjik": return "Coşkulu"
    case "mutlu": return "Mutlu"
    case "dogal": return "Doğal"
    case "huzurlu": return "Huzurlu"
    case "heyecanli": return "Özgür"
    case "stabil": return "Derin"
    case "uzgun": return "Nostaljik"
    case "sinirli": return "Gizemli"
    case "stresli": return "Hassas"
    case "yorgun": return "Sessiz"
    case "sakin": return "Huzurlu"
    default: return "Huzurlu"
    }
}
