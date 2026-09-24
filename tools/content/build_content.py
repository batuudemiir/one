#!/usr/bin/env python3
"""ONE 2.0 içerik üretim hattı (04_arka_plan_motorlari.md › E18).

Kaynak: Google Sheets → dışa aktarılan CSV (quotes, prompts, themes, echoes)
+ JSON katalogları (emotions, causes, badges, paths) ve rehberli günlükler.
Çıktı: uygulamanın okuduğu içerik şeması v1 JSON'ları + manifest (SHA-256).

Doğrulayıcı hata verirse çıkış kodu 1: yayın yok (CI'da da koşar).

Kullanım:
  # CSV'den derle, doğrula, yaz
  python3 tools/content/build_content.py build \\
      --csv tools/content/templates --catalogs one/ONE2/Content/Bundled \\
      --out build/content/v1 --content-version 2 [--previous one/ONE2/Content/Bundled]

  # Var olan bir JSON içerik klasörünü doğrula (bundle, yayın klasörü)
  python3 tools/content/build_content.py validate one/ONE2/Content/Bundled

Yalnız Python standart kütüphanesi kullanılır.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from datetime import datetime, timezone

SCHEMA_VERSION = "1.0"
NOTE_KEY = "_note"

# Sabit tema sözlüğü (E2.1): yeni etiket önce buraya eklenir.
THEMES = {
    "yavaslik", "cesaret", "minnet", "kayip", "odak", "kabul", "sinirlar", "iliskiler",
    "dinlenme", "degisim", "ozsefkat", "anlam", "umut", "sabir", "merak",
}
QUOTE_KINDS = {"quote", "affirmation", "proverb", "reflection"}
TRANSLATIONS = {"original", "oneTranslation", "publicDomainTranslation"}
LICENSES = {"publicDomain", "original", "licensed"}
DAY_PARTS = {"morning", "day", "evening", "any"}
PROMPT_POOLS = {"free", "reflection", "checkinFollowUp", "morning", "evening"}
TRENDS = {"up", "down", "flat"}
ANSWER_KINDS = {"text", "scale5", "yesNo", "singleChoice", "multiChoice", "focus", "todo"}

ID_PATTERNS = {
    "quote": re.compile(r"^q_\d{6}$"),
    "prompt": re.compile(r"^p_\w+$"),
    "theme": re.compile(r"^t_(\d{4}w\d{2}|ev_\d{3})$"),
    "echo": re.compile(r"^e_\d{6}$"),
}
QUOTE_LENGTH = (12, 220)
DUPLICATE_THRESHOLD = 0.85

# Ton (E6 ve olumlamalar): mutlak vaat, sonuç vaadi, baskı.
ABSOLUTE_WORDS = ["asla", "her zaman", "kesinlikle", "mutlaka", "hiçbir zaman"]
RESULT_PROMISE = re.compile(r"\b\d+\s*(gün|hafta|ay|dakika)(de|da|te|ta)\b", re.IGNORECASE)
PRESSURE_WORDS = ["neşelen", "gülümse", "pozitif ol", "üzülme", "takma kafana"]
EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-⛿✀-➿]")


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def error(self, where: str, message: str) -> None:
        self.errors.append(f"{where}: {message}")

    def warn(self, where: str, message: str) -> None:
        self.warnings.append(f"{where}: {message}")

    @property
    def ok(self) -> bool:
        return not self.errors


# ---------------------------------------------------------------------------
# Metin kuralları


def normalize(text: str) -> str:
    """Küçük harf, aksansız, noktalamasız (tekrar tespiti için)."""
    text = text.replace("İ", "i").replace("I", "ı").lower()
    text = text.translate(str.maketrans("çğıöşüâîû", "cgiosuaiu"))
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r"[^\w\s]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def trigrams(text: str) -> set[str]:
    t = f"  {normalize(text)} "
    return {t[i:i + 3] for i in range(len(t) - 2)}


def jaccard(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def check_typography(where: str, text: str, report: Report) -> None:
    """Türkçe yazım: tipografik tırnak, çift/sonda boşluk, İ/ı."""
    if '"' in text:
        report.error(where, 'düz çift tırnak (") yerine “ ” kullan')
    if re.search(r"\w'\w", text):
        report.error(where, "düz kesme işareti (') yerine ’ kullan")
    if "  " in text:
        report.error(where, "çift boşluk")
    if text != text.strip():
        report.error(where, "başta/sonda boşluk")
    if "̇" in text:
        report.error(where, "birleşik nokta (i̇): İ/i yanlış küçültülmüş")
    # İ/ı sezgisi: "I" ile başlayıp ön ünlü taşıyan kelime büyük olasılıkla "İ" olmalı.
    for word in re.findall(r"\bI[a-zçğıöşü]+", text):
        if re.search(r"[eiöü]", word[1:]) and not re.search(r"[aıou]", word[1:]):
            report.warn(where, f"“{word}” büyük olasılıkla “İ{word[1:]}” olmalı")


def check_tone(where: str, text: str, report: Report) -> None:
    low = text.lower()
    if "!" in text:
        report.error(where, "ünlem")
    if EMOJI.search(text):
        report.error(where, "emoji")
    for word in ABSOLUTE_WORDS:
        if re.search(rf"\b{re.escape(word)}\b", low):
            report.error(where, f"mutlak vaat: “{word}”")
    if RESULT_PROMISE.search(text):
        report.error(where, "sonuç vaadi (ör. “30 günde”)")
    for word in PRESSURE_WORDS:
        if word in low:
            report.error(where, f"baskı dili: “{word}”")


# ---------------------------------------------------------------------------
# CSV → öğe


def split_list(value: str) -> list[str]:
    return [v.strip() for v in (value or "").split(";") if v.strip()]


def to_bool(value: str, default: bool) -> bool:
    v = (value or "").strip().lower()
    if not v:
        return default
    return v in {"1", "true", "evet", "yes", "x"}


def to_int(value: str, default: int | None = None) -> int | None:
    v = (value or "").strip()
    return int(v) if v else default


def base_fields(row: dict, content_version: int) -> dict:
    return {
        "premium": to_bool(row.get("premium", ""), False),
        "active": to_bool(row.get("active", ""), True),
        "addedIn": to_int(row.get("addedIn", ""), content_version),
        "lang": (row.get("lang") or "tr").strip(),
    }


def quote_length(text: str) -> str:
    return "short" if len(text) < 60 else ("medium" if len(text) <= 140 else "long")


def read_csv(path: str) -> list[dict]:
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    # Şablon yorum satırları: id "#" ile başlar.
    return [r for r in rows if not (r.get("id") or "").startswith("#")]


def quotes_from_csv(rows: list[dict], cv: int) -> list[dict]:
    out = []
    for r in rows:
        text = r.get("text", "")
        item = {
            "id": r.get("id", "").strip(), "text": text, "kind": r.get("kind", "").strip(),
            "license": r.get("license", "").strip(),
            "themes": split_list(r.get("themes", "")), "paths": split_list(r.get("paths", "")),
            "emotionFit": split_list(r.get("emotionFit", "")),
            "moodFit": [int(x) for x in split_list(r.get("moodFit", ""))],
            "timeOfDay": (r.get("timeOfDay") or "any").strip(), "length": quote_length(text),
        }
        for key in ("author", "source", "translation", "licenseNote"):
            if (r.get(key) or "").strip():
                item[key] = r[key].strip()
        if split_list(r.get("reflectionPromptIDs", "")):
            item["reflectionPromptIDs"] = split_list(r["reflectionPromptIDs"])
        item.update(base_fields(r, cv))
        out.append(item)
    return out


def prompts_from_csv(rows: list[dict], cv: int) -> list[dict]:
    out = []
    for r in rows:
        item = {
            "id": r.get("id", "").strip(), "text": r.get("text", ""), "pool": r.get("pool", "").strip(),
            "themes": split_list(r.get("themes", "")), "timeOfDay": (r.get("timeOfDay") or "any").strip(),
            "moodFit": [int(x) for x in split_list(r.get("moodFit", ""))],
            "emotionFit": split_list(r.get("emotionFit", "")), "quoteIDs": split_list(r.get("quoteIDs", "")),
            "isCore": to_bool(r.get("isCore", ""), False),
        }
        item.update(base_fields(r, cv))
        out.append(item)
    return out


def themes_from_csv(rows: list[dict], cv: int) -> list[dict]:
    out = []
    for r in rows:
        item = {
            "id": r.get("id", "").strip(), "title": r.get("title", ""), "summary": r.get("summary", ""),
            "tags": split_list(r.get("tags", "")),
            "days": [{"day": d, "prompt": r.get(f"day{d}", "")} for d in range(1, 8)],
        }
        if (r.get("week") or "").strip():
            item["week"] = r["week"].strip()
        item.update(base_fields(r, cv))
        out.append(item)
    return out


def echoes_from_csv(rows: list[dict], cv: int) -> list[dict]:
    out = []
    for r in rows:
        cond: dict = {}
        if split_list(r.get("scoreIn", "")):
            cond["scoreIn"] = [int(x) for x in split_list(r["scoreIn"])]
        for key in ("emotionFamilyAny", "causeAny"):
            if split_list(r.get(key, "")):
                cond[key] = split_list(r[key])
        for key in ("timeOfDay", "trend"):
            if (r.get(key) or "").strip():
                cond[key] = r[key].strip()
        if (r.get("firstCheckin") or "").strip():
            cond["firstCheckin"] = to_bool(r["firstCheckin"], False)
        item = {"id": r.get("id", "").strip(), "text": r.get("text", ""), "conditions": cond,
                "weight": float(r.get("weight") or 1)}
        item.update(base_fields(r, cv))
        out.append(item)
    return out


# ---------------------------------------------------------------------------
# Doğrulama


@dataclass
class Content:
    quotes: list[dict] = field(default_factory=list)
    prompts: list[dict] = field(default_factory=list)
    themes: list[dict] = field(default_factory=list)          # takvim temaları (week dolu)
    evergreen: list[dict] = field(default_factory=list)
    echoes: list[dict] = field(default_factory=list)
    emotions: list[dict] = field(default_factory=list)
    causes: list[dict] = field(default_factory=list)
    badges: list[dict] = field(default_factory=list)
    paths: list[dict] = field(default_factory=list)
    guided: list[dict] = field(default_factory=list)

    def all_ids(self) -> dict[str, str]:
        """ID → tür (yeniden kullanım denetimi için)."""
        out = {}
        for kind, items in [("quote", self.quotes), ("prompt", self.prompts), ("theme", self.themes + self.evergreen),
                            ("echo", self.echoes), ("emotion", self.emotions), ("cause", self.causes),
                            ("badge", self.badges), ("path", self.paths), ("guided", self.guided)]:
            for item in items:
                out[item.get("id", "")] = kind
        return out


def require(item: dict, keys: list[str], where: str, report: Report) -> None:
    for key in keys:
        if item.get(key) in (None, "", []):
            report.error(where, f"zorunlu alan eksik: {key}")


def check_common(item: dict, where: str, report: Report) -> None:
    for key, kind in (("active", bool), ("premium", bool), ("addedIn", int), ("lang", str)):
        if not isinstance(item.get(key), kind):
            report.error(where, f"{key} eksik ya da yanlış tipte")


def check_unique(items: list[dict], kind: str, report: Report) -> None:
    seen: set[str] = set()
    pattern = ID_PATTERNS.get(kind)
    for item in items:
        iid = item.get("id", "")
        if iid in seen:
            report.error(f"{kind}:{iid}", "ID çakışması")
        seen.add(iid)
        if pattern and not pattern.match(iid):
            report.error(f"{kind}:{iid}", f"ID biçimi geçersiz ({pattern.pattern})")


def validate(c: Content, report: Report, previous: Content | None = None) -> Report:
    families = {e.get("family") for e in c.emotions}
    path_ids = {p.get("id") for p in c.paths}
    cause_ids = {x.get("id") for x in c.causes}
    quote_ids = {q.get("id") for q in c.quotes}
    prompt_ids = {p.get("id") for p in c.prompts}

    for kind, items in [("quote", c.quotes), ("prompt", c.prompts), ("theme", c.themes + c.evergreen),
                        ("echo", c.echoes), ("emotion", c.emotions), ("cause", c.causes),
                        ("badge", c.badges), ("path", c.paths), ("guided", c.guided)]:
        check_unique(items, kind, report)
        for item in items:
            check_common(item, f"{kind}:{item.get('id')}", report)

    for q in c.quotes:
        w = f"quote:{q.get('id')}"
        require(q, ["id", "text", "kind", "license"], w, report)
        text = q.get("text", "")
        if not QUOTE_LENGTH[0] <= len(text) <= QUOTE_LENGTH[1]:
            report.error(w, f"uzunluk {len(text)} (izinli {QUOTE_LENGTH[0]}–{QUOTE_LENGTH[1]})")
        if q.get("kind") not in QUOTE_KINDS:
            report.error(w, f"bilinmeyen tür: {q.get('kind')}")
        if q.get("license") not in LICENSES:
            report.error(w, f"bilinmeyen lisans: {q.get('license')}")
        if q.get("license") == "licensed" and not q.get("licenseNote"):
            report.error(w, "licensed ise licenseNote zorunlu")
        if q.get("kind") == "quote":
            # Kaynağı doğrulanamayan "internette X'e atfedilen" söz eklenmez.
            require(q, ["author", "source", "translation"], w, report)
        if q.get("translation") and q.get("translation") not in TRANSLATIONS:
            report.error(w, f"bilinmeyen çeviri: {q.get('translation')}")
        if q.get("length") and q.get("length") != quote_length(text):
            report.error(w, f"length alanı {q.get('length')}, metne göre {quote_length(text)}")
        unknown = set(q.get("themes", [])) - THEMES
        if unknown:
            report.error(w, f"bilinmeyen tema: {sorted(unknown)}")
        if set(q.get("paths", [])) - path_ids:
            report.error(w, f"bilinmeyen yol: {sorted(set(q.get('paths', [])) - path_ids)}")
        if set(q.get("emotionFit", [])) - families:
            report.error(w, f"bilinmeyen duygu ailesi: {sorted(set(q.get('emotionFit', [])) - families)}")
        if any(s not in range(1, 6) for s in q.get("moodFit", [])):
            report.error(w, "moodFit 1–5 dışında")
        if q.get("timeOfDay", "any") not in DAY_PARTS:
            report.error(w, "timeOfDay geçersiz")
        for pid in q.get("reflectionPromptIDs", []) or []:
            if pid not in prompt_ids:
                report.error(w, f"reflectionPromptIDs bilinmeyen soru: {pid}")
        check_typography(w, text, report)
        if q.get("kind") in {"affirmation", "reflection"}:
            check_tone(w, text, report)

    for p in c.prompts:
        w = f"prompt:{p.get('id')}"
        require(p, ["id", "text", "pool"], w, report)
        if p.get("pool") not in PROMPT_POOLS:
            report.error(w, f"bilinmeyen havuz: {p.get('pool')}")
        if set(p.get("themes", [])) - THEMES:
            report.error(w, f"bilinmeyen tema: {sorted(set(p.get('themes', [])) - THEMES)}")
        for qid in p.get("quoteIDs", []):
            if qid not in quote_ids:
                report.error(w, f"quoteIDs bilinmeyen söz: {qid}")
        check_typography(w, p.get("text", ""), report)
        if "!" in p.get("text", "") or EMOJI.search(p.get("text", "")):
            report.error(w, "ünlem ya da emoji")

    for t in c.themes + c.evergreen:
        w = f"theme:{t.get('id')}"
        require(t, ["id", "title", "summary", "days"], w, report)
        days = t.get("days", [])
        if sorted(d.get("day") for d in days) != list(range(1, 8)) or any(not d.get("prompt") for d in days):
            report.error(w, "7 günün her biri için soru gerekli (1 = pazartesi)")
        if set(t.get("tags", [])) - THEMES:
            report.error(w, f"bilinmeyen tema etiketi: {sorted(set(t.get('tags', [])) - THEMES)}")
        week = t.get("week")
        if week:
            m = re.match(r"^(\d{4})-W(\d{2})$", week)
            if not m:
                report.error(w, f"hafta biçimi geçersiz: {week}")
            elif t.get("id") != f"t_{m.group(1)}w{m.group(2)}":
                report.error(w, f"ID haftayla uyuşmuyor ({week})")
        for d in days:
            check_typography(f"{w}:d{d.get('day')}", d.get("prompt", ""), report)
    weeks = [t.get("week") for t in c.themes]
    if len(weeks) != len(set(weeks)):
        report.error("themes", "aynı hafta için birden çok tema")

    for e in c.echoes:
        w = f"echo:{e.get('id')}"
        require(e, ["id", "text"], w, report)
        cond = e.get("conditions", {})
        if any(s not in range(1, 6) for s in cond.get("scoreIn", [])):
            report.error(w, "scoreIn 1–5 dışında")
        if set(cond.get("emotionFamilyAny", [])) - families:
            report.error(w, "bilinmeyen duygu ailesi")
        if set(cond.get("causeAny", [])) - cause_ids:
            report.error(w, "bilinmeyen neden")
        if cond.get("timeOfDay") and cond["timeOfDay"] not in DAY_PARTS:
            report.error(w, "timeOfDay geçersiz")
        if cond.get("trend") and cond["trend"] not in TRENDS:
            report.error(w, "trend geçersiz")
        if not isinstance(e.get("weight"), (int, float)) or e.get("weight", 0) <= 0:
            report.error(w, "weight > 0 olmalı")
        check_typography(w, e.get("text", ""), report)
        check_tone(w, e.get("text", ""), report)

    for g in c.guided:
        w = f"guided:{g.get('id')}"
        for step in g.get("steps", []):
            if step.get("kind") not in ANSWER_KINDS:
                report.error(w, f"bilinmeyen adım türü: {step.get('kind')}")

    check_duplicates(c.quotes, "quote", report)
    check_duplicates([p for p in c.prompts], "prompt", report)
    check_duplicates(c.echoes, "echo", report)

    if previous is not None:
        check_id_history(c, previous, report)
    return report


def check_duplicates(items: list[dict], kind: str, report: Report) -> None:
    """Normalize metinde trigram Jaccard > 0,85 olan çiftler hata."""
    grams = [(item.get("id"), item.get("text", ""), trigrams(item.get("text", ""))) for item in items]
    grams.sort(key=lambda g: len(g[2]))
    for i, (aid, _, a) in enumerate(grams):
        for bid, _, b in grams[i + 1:]:
            # |A∩B|/|A∪B| ≤ |A|/|B|: boy farkı büyükse benzerlik eşiği aşılamaz.
            if len(a) < DUPLICATE_THRESHOLD * len(b):
                break
            score = jaccard(a, b)
            if score > DUPLICATE_THRESHOLD:
                report.error(f"{kind}:{aid}", f"{bid} ile neredeyse aynı (Jaccard {score:.2f})")


def check_id_history(c: Content, previous: Content, report: Report) -> None:
    """Yayınlanmış ID silinmez (active:false olur) ve başka türe verilmez."""
    now = c.all_ids()
    for iid, kind in previous.all_ids().items():
        if iid not in now:
            report.error(f"{kind}:{iid}", "yayınlanmış ID silinmiş; silmek yerine active:false yap")
        elif now[iid] != kind:
            report.error(f"{kind}:{iid}", f"ID başka türe yeniden verilmiş ({now[iid]})")


# ---------------------------------------------------------------------------
# JSON okuma/yazma


def load_items(path: str) -> list[dict]:
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as f:
        return json.load(f).get("items", [])


def load_json_dir(root: str) -> Content:
    c = Content(
        quotes=load_items(os.path.join(root, "quotes.tr.json")),
        prompts=load_items(os.path.join(root, "prompts.tr.json")),
        evergreen=load_items(os.path.join(root, "themes", "evergreen.tr.json")),
        echoes=load_items(os.path.join(root, "echoes.tr.json")),
        emotions=load_items(os.path.join(root, "catalogs", "emotions.tr.json")),
        causes=load_items(os.path.join(root, "catalogs", "causes.tr.json")),
        badges=load_items(os.path.join(root, "catalogs", "badges.tr.json")),
        paths=load_items(os.path.join(root, "catalogs", "paths.tr.json")),
    )
    themes_dir = os.path.join(root, "themes")
    if os.path.isdir(themes_dir):
        for name in sorted(os.listdir(themes_dir)):
            if name.endswith(".tr.json") and name != "evergreen.tr.json":
                c.themes += load_items(os.path.join(themes_dir, name))
    guided_dir = os.path.join(root, "guided")
    if os.path.isdir(guided_dir):
        for name in sorted(os.listdir(guided_dir)):
            if name.endswith(".json"):
                c.guided += load_items(os.path.join(guided_dir, name))
    return c


def verify_manifest(root: str, report: Report) -> None:
    path = os.path.join(root, "manifest.json")
    if not os.path.exists(path):
        report.error("manifest", "manifest.json yok")
        return
    with open(path, encoding="utf-8") as f:
        manifest = json.load(f)
    major = str(manifest.get("schemaVersion", "")).split(".")[0]
    if major != SCHEMA_VERSION.split(".")[0]:
        report.error("manifest", f"schemaVersion {manifest.get('schemaVersion')} desteklenmiyor")
    for entry in manifest.get("files", []):
        fpath = os.path.join(root, entry["path"])
        if not os.path.exists(fpath):
            report.error("manifest", f"dosya yok: {entry['path']}")
            continue
        with open(fpath, "rb") as f:
            if hashlib.sha256(f.read()).hexdigest() != entry["sha256"].lower():
                report.error("manifest", f"hash uyuşmuyor: {entry['path']}")


def dump(obj: dict) -> bytes:
    return (json.dumps(obj, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def write_content(c: Content, out: str, content_version: int, note: str | None = None) -> dict:
    files: dict[str, dict] = {
        "quotes.tr.json": {"items": c.quotes},
        "prompts.tr.json": {"items": c.prompts},
        "echoes.tr.json": {"items": c.echoes},
        "themes/evergreen.tr.json": {"items": c.evergreen},
        "catalogs/emotions.tr.json": {"items": c.emotions},
        "catalogs/causes.tr.json": {"items": c.causes},
        "catalogs/badges.tr.json": {"items": c.badges},
        "catalogs/paths.tr.json": {"items": c.paths},
    }
    for t in c.themes:
        year, week = t["week"].split("-W")
        files[f"themes/{year}-w{week}.tr.json"] = {"items": [t]}
    for g in c.guided:
        files[f"guided/{g['id']}.tr.json"] = {"items": [g]}
    entries = []
    for rel in sorted(files):
        payload = files[rel]
        if note:
            payload = {NOTE_KEY: note, **payload}
        data = dump(payload)
        full = os.path.join(out, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "wb") as f:
            f.write(data)
        entries.append({"path": rel, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)})
    manifest = {"schemaVersion": SCHEMA_VERSION, "contentVersion": content_version,
                "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "files": entries}
    if note:
        manifest = {NOTE_KEY: note, **manifest}
    with open(os.path.join(out, "manifest.json"), "wb") as f:
        f.write(dump(manifest))
    return manifest


def build_from_csv(csv_dir: str, catalogs_dir: str, content_version: int) -> Content:
    base = load_json_dir(catalogs_dir)
    themes = themes_from_csv(read_csv(os.path.join(csv_dir, "themes.csv")), content_version)
    return Content(
        quotes=quotes_from_csv(read_csv(os.path.join(csv_dir, "quotes.csv")), content_version),
        prompts=prompts_from_csv(read_csv(os.path.join(csv_dir, "prompts.csv")), content_version),
        themes=[t for t in themes if t.get("week")],
        evergreen=[t for t in themes if not t.get("week")],
        echoes=echoes_from_csv(read_csv(os.path.join(csv_dir, "echoes.csv")), content_version),
        emotions=base.emotions, causes=base.causes, badges=base.badges, paths=base.paths, guided=base.guided,
    )


def print_report(report: Report) -> None:
    for w in report.warnings:
        print(f"uyarı  {w}")
    for e in report.errors:
        print(f"HATA   {e}")
    print(f"{len(report.errors)} hata, {len(report.warnings)} uyarı")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="ONE 2.0 içerik derleyici ve doğrulayıcı (E18)")
    sub = parser.add_subparsers(dest="command", required=True)
    b = sub.add_parser("build", help="CSV'den JSON + manifest üret")
    b.add_argument("--csv", required=True)
    b.add_argument("--catalogs", required=True, help="kataloglar ve rehberli günlükler (JSON)")
    b.add_argument("--out", required=True)
    b.add_argument("--content-version", type=int, required=True)
    b.add_argument("--previous", help="son yayınlanmış içerik klasörü (ID geçmişi denetimi)")
    b.add_argument("--note", help="dosyalara _note olarak eklenir (ör. PLACEHOLDER)")
    v = sub.add_parser("validate", help="JSON içerik klasörünü doğrula")
    v.add_argument("root")
    v.add_argument("--previous")
    args = parser.parse_args(argv)

    report = Report()
    previous = load_json_dir(args.previous) if getattr(args, "previous", None) else None
    if args.command == "build":
        content = build_from_csv(args.csv, args.catalogs, args.content_version)
        validate(content, report, previous)
        if report.ok:
            write_content(content, args.out, args.content_version, args.note)
    else:
        verify_manifest(args.root, report)
        validate(load_json_dir(args.root), report, previous)
    print_report(report)
    return 0 if report.ok else 1


if __name__ == "__main__":
    sys.exit(main())
