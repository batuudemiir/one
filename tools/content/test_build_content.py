#!/usr/bin/env python3
"""build_content.py doğrulayıcı testleri (yalnız standart kütüphane).

Koşturma: python3 -m unittest tools/content/test_build_content.py
"""

import copy
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_content as bc  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BUNDLE = os.path.join(ROOT, "one", "ONE2", "Content", "Bundled")
TEMPLATES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates")


def base_content() -> bc.Content:
    return bc.load_json_dir(BUNDLE)


def errors(content: bc.Content, previous: bc.Content | None = None) -> list[str]:
    return bc.validate(content, bc.Report(), previous).errors


def quote(**overrides) -> dict:
    q = {"id": "q_900001", "text": "Pencereyi açmak da bir başlangıçtır.", "kind": "affirmation", "license": "original",
         "themes": ["cesaret"], "paths": ["cesur"], "emotionFit": [], "moodFit": [2], "timeOfDay": "any",
         "length": "short", "premium": False, "active": True, "addedIn": 2, "lang": "tr"}
    q.update(overrides)
    return q


class BundleTests(unittest.TestCase):
    def test_bundle_is_valid(self):
        report = bc.Report()
        bc.verify_manifest(BUNDLE, report)
        bc.validate(base_content(), report)
        self.assertEqual(report.errors, [])

    def test_templates_build_and_validate(self):
        with tempfile.TemporaryDirectory() as out:
            code = bc.main(["build", "--csv", TEMPLATES, "--catalogs", BUNDLE, "--out", out,
                            "--content-version", "2"])
            self.assertEqual(code, 0)
            self.assertEqual(bc.main(["validate", out]), 0)
            with open(os.path.join(out, "manifest.json"), encoding="utf-8") as f:
                manifest = json.load(f)
            self.assertEqual(manifest["contentVersion"], 2)
            paths = {e["path"] for e in manifest["files"]}
            self.assertIn("themes/2026-w42.tr.json", paths)
            self.assertIn("quotes.tr.json", paths)


class SchemaTests(unittest.TestCase):
    def check(self, q: dict, fragment: str):
        c = base_content()
        c.quotes.append(q)
        errs = [e for e in errors(c) if "q_900001" in e]
        self.assertTrue(any(fragment in e for e in errs), f"{fragment!r} bekleniyordu: {errs}")

    def test_valid_new_quote(self):
        c = base_content()
        c.quotes.append(quote())
        self.assertEqual(errors(c), [])

    def test_length_limits(self):
        self.check(quote(text="Kısa."), "uzunluk")
        self.check(quote(text="a" * 221, length="long"), "uzunluk")

    def test_unknown_theme_path_family(self):
        self.check(quote(themes=["mutluluk"]), "bilinmeyen tema")
        self.check(quote(paths=["gizli"]), "bilinmeyen yol")
        self.check(quote(emotionFit=["coskun"]), "bilinmeyen duygu ailesi")

    def test_quote_requires_source(self):
        # İnternette atfedilen, kaynaksız söz eklenmez.
        self.check(quote(kind="quote", author="Mevlana"), "zorunlu alan eksik: source")
        self.check(quote(kind="quote", author="Seneca", source="Mektuplar"), "zorunlu alan eksik: translation")

    def test_licensed_needs_note(self):
        self.check(quote(license="licensed"), "licenseNote")

    def test_wrong_length_field(self):
        self.check(quote(length="long"), "length alanı")

    def test_id_format_and_collision(self):
        self.check(quote(id="q_900001x"), "ID biçimi")
        c = base_content()
        c.quotes.append(quote(id=c.quotes[0]["id"], text="Tamamen başka bir cümle burada duruyor."))
        self.assertTrue(any("ID çakışması" in e for e in errors(c)))

    def test_theme_needs_seven_days(self):
        c = base_content()
        t = copy.deepcopy(c.evergreen[0])
        t["id"] = "t_ev_900"
        t["days"] = t["days"][:6]
        c.evergreen.append(t)
        self.assertTrue(any("7 günün" in e for e in errors(c)))

    def test_theme_week_id_mismatch(self):
        c = base_content()
        t = copy.deepcopy(c.themes[0])
        t["id"] = "t_2026w50"
        t["week"] = "2026-W51"
        c.themes.append(t)
        self.assertTrue(any("ID haftayla uyuşmuyor" in e for e in errors(c)))

    def test_dangling_references(self):
        c = base_content()
        c.quotes.append(quote(reflectionPromptIDs=["p_yok"]))
        c.echoes.append({"id": "e_900001", "text": "Bugünün de yerini aldı, yine.", "conditions": {"causeAny": ["c_yok"]},
                         "weight": 1, "premium": False, "active": True, "addedIn": 2, "lang": "tr"})
        errs = errors(c)
        self.assertTrue(any("reflectionPromptIDs" in e for e in errs))
        self.assertTrue(any("bilinmeyen neden" in e for e in errs))


class EmotionCatalogTests(unittest.TestCase):
    def test_ux_contract(self):
        emotions = base_content().emotions
        self.assertEqual(len(emotions), 38)
        self.assertEqual({e["family"] for e in emotions}, bc.EMOTION_FAMILIES)
        self.assertEqual(emotions[0]["id"], "nese.minnettar")

    def test_bad_id_and_family(self):
        c = base_content()
        c.emotions.append({"id": "emo_yeni", "label": "Yeni", "family": "merak",
                           "premium": False, "active": True, "addedIn": 2, "lang": "tr"})
        errs = [e for e in errors(c) if "emo_yeni" in e]
        self.assertTrue(any("ID biçimi" in e for e in errs))
        self.assertTrue(any("bilinmeyen aile" in e for e in errs))
        self.assertTrue(any("öneki" in e for e in errs))


class TurkishTests(unittest.TestCase):
    def report(self, text: str) -> bc.Report:
        r = bc.Report()
        bc.check_typography("x", text, r)
        return r

    def test_straight_quotes(self):
        self.assertTrue(self.report('Dedi ki "dur".').errors)
        self.assertTrue(self.report("Lucilius'a mektup.").errors)
        self.assertFalse(self.report("Lucilius’a “mektup”.").errors)

    def test_spaces(self):
        self.assertTrue(any("çift boşluk" in e for e in self.report("Bir  iki.").errors))
        self.assertTrue(any("sonda" in e for e in self.report("Bir iki. ").errors))

    def test_dotted_i(self):
        self.assertTrue(self.report("i̇stanbul").errors)
        self.assertTrue(self.report("Iyi günler.").warnings)
        self.assertFalse(self.report("Işık ve Irmak.").warnings)


class ToneTests(unittest.TestCase):
    def errs(self, text: str) -> list[str]:
        r = bc.Report()
        bc.check_tone("x", text, r)
        return r.errors

    def test_tone_rules(self):
        self.assertTrue(self.errs("Harika bir gün!"))
        self.assertTrue(self.errs("Bu his asla geçmez."))
        self.assertTrue(self.errs("Her zaman güçlüsün."))
        self.assertTrue(self.errs("30 günde değişirsin."))
        self.assertTrue(self.errs("Neşelen biraz."))
        self.assertTrue(self.errs("Güzel gün \U0001F60A"))
        self.assertFalse(self.errs("Zor bir gün olduğunu yazman da bir adım."))

    def test_echo_tone_enforced_in_validate(self):
        c = base_content()
        c.echoes.append({"id": "e_900002", "text": "Neşelen, her şey düzelecek!", "conditions": {"scoreIn": [1]},
                         "weight": 1, "premium": False, "active": True, "addedIn": 2, "lang": "tr"})
        errs = [e for e in errors(c) if "e_900002" in e]
        self.assertTrue(any("ünlem" in e for e in errs))
        self.assertTrue(any("baskı dili" in e for e in errs))


class DuplicateTests(unittest.TestCase):
    def test_near_duplicate(self):
        c = base_content()
        c.quotes.append(quote(text="Yavaş yürüyen tez varır!", kind="proverb", license="publicDomain"))
        errs = errors(c)
        self.assertTrue(any("neredeyse aynı" in e for e in errs), errs)

    def test_different_texts_pass(self):
        a, b = bc.trigrams("Damlaya damlaya göl olur."), bc.trigrams("Sabır acıdır, meyvesi tatlıdır.")
        self.assertLess(bc.jaccard(a, b), 0.3)
        self.assertEqual(bc.normalize("ŞÜKRAN, İyi!"), "sukran iyi")


class IdHistoryTests(unittest.TestCase):
    def test_deleted_id_is_error_inactive_is_fine(self):
        previous = base_content()
        now = base_content()
        removed = now.quotes.pop()
        errs = errors(now, previous)
        self.assertTrue(any(removed["id"] in e and "silinmiş" in e for e in errs))

        now = base_content()
        now.quotes[-1]["active"] = False
        self.assertEqual(errors(now, previous), [])

    def test_reused_for_other_kind(self):
        previous = base_content()
        now = base_content()
        stolen = now.prompts[0]["id"]
        now.quotes.append(quote(id="q_900001"))
        now.prompts[0]["id"] = "p_900001"
        now.echoes.append({"id": stolen, "text": "Başka türde bir yankı cümlesi.", "conditions": {},
                           "weight": 1, "premium": False, "active": True, "addedIn": 2, "lang": "tr"})
        errs = errors(now, previous)
        self.assertTrue(any(stolen in e for e in errs))


class ManifestTests(unittest.TestCase):
    def test_hash_mismatch_and_schema(self):
        with tempfile.TemporaryDirectory() as out:
            bc.write_content(base_content(), out, 3)
            with open(os.path.join(out, "quotes.tr.json"), "a", encoding="utf-8") as f:
                f.write(" ")
            report = bc.Report()
            bc.verify_manifest(out, report)
            self.assertTrue(any("hash" in e for e in report.errors))

            with open(os.path.join(out, "manifest.json"), encoding="utf-8") as f:
                manifest = json.load(f)
            manifest["schemaVersion"] = "2.0"
            with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as f:
                json.dump(manifest, f)
            report = bc.Report()
            bc.verify_manifest(out, report)
            self.assertTrue(any("schemaVersion" in e for e in report.errors))

    def test_build_refuses_invalid_csv(self):
        with tempfile.TemporaryDirectory() as csv_dir, tempfile.TemporaryDirectory() as out:
            with open(os.path.join(csv_dir, "quotes.csv"), "w", encoding="utf-8") as f:
                f.write("id,text,kind,license,themes,paths\nq_900009,Harika!,affirmation,original,mutluluk,cesur\n")
            code = bc.main(["build", "--csv", csv_dir, "--catalogs", BUNDLE, "--out", out, "--content-version", "2"])
            self.assertEqual(code, 1)
            self.assertFalse(os.path.exists(os.path.join(out, "manifest.json")))


if __name__ == "__main__":
    unittest.main()
