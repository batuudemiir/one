# Phase 2: Implement — Push Metadata to App Store Connect

**Run:** Bi-weekly (after Phase 1 completes)
**Requires:** ASC CLI authenticated, Phase 1 research outputs
**Output directory:** `./aso-data/backup/`, `./aso-data/changelog/`

---

## Pre-Flight: Set Variables

```bash
APP_ID="<YOUR_APP_STORE_ID>"        # From Astro list_apps or ASC
DATE=$(date +%Y-%m-%d)
RESEARCH_DIR="./aso-data/research"
BACKUP_DIR="./aso-data/backup"
CHANGELOG="./aso-data/changelog/metadata_changes_${DATE}.json"

# Verify ASC CLI is authenticated
asc apps list
```

---

## Step 2.1 — Build Optimized Metadata per Locale

Using the recommended keyword lists from Phase 1, construct metadata for each locale.

### Metadata Construction Rules

| Field | Max | Strategy |
|---|---|---|
| Title | 30 chars | Brand name + #1 highest-priority keyword |
| Subtitle | 30 chars | #2 and #3 keywords, natural phrasing |
| Keyword field | 100 chars | Remaining keywords, comma-separated, NO spaces |
| Description | 4000 chars | Keyword-rich but readable; first 3 lines are critical |

**Hard rules:**
- NO duplicate words across title + subtitle + keyword field (Apple deduplicates — wasted slots)
- Keyword field: `word1,word2,word3` — no spaces after commas
- No app name or category name in keyword field
- Use singular forms (Apple auto-matches plural)
- Prioritize: high popularity + low difficulty first
- Count characters carefully before pushing

### Example (en-US)

Given recommended keywords: `daily journal` (pop:72, diff:38), `mood tracker` (pop:65, diff:41), `diary app` (pop:58, diff:35), `personal log` (pop:44, diff:28), `memory keeper` (pop:39, diff:22), `life journal` (pop:36, diff:30), `reflection` (pop:33, diff:19), `gratitude` (pop:31, diff:25), `habit` (pop:68, diff:55), `mindfulness` (pop:61, diff:52)

```
Title (29 chars):    "ONE — Your Daily Journal"
Subtitle (29 chars): "Mood Tracker & Memory Keeper"
Keywords (98 chars): "diary,personal,log,life,reflection,gratitude,habit,mindfulness,memory,capture,moments"
```

Note: "daily", "journal", "mood", "tracker", "memory", "keeper" are NOT in keyword field (already in title/subtitle).

---

## Step 2.2 — Backup Current Metadata (ALWAYS FIRST)

**Never skip this step. ASC changes are immediate.**

```bash
# Backup current metadata for each locale before any changes
for LOCALE in us gb de ja fr es br it nl ko tr; do
  asc apps info get \
    --app-id $APP_ID \
    --locale $LOCALE \
    > "${BACKUP_DIR}/${LOCALE}_metadata_before_${DATE}.json"

  echo "Backed up: $LOCALE"
done
```

---

## Step 2.3 — Push Keyword Field Updates

Keyword field and subtitle can be pushed **without a new binary submission**.

```bash
# Example for US locale
asc apps info update \
  --app-id $APP_ID \
  --locale en-US \
  --keywords "diary,personal,log,life,reflection,gratitude,habit,mindfulness,memory,capture"

# Subtitle update
asc apps info update \
  --app-id $APP_ID \
  --locale en-US \
  --subtitle "Mood Tracker & Memory Keeper"
```

**IMPORTANT:** Title changes require a new binary submission — only change with planned version releases.

### Full locale push sequence

Run for each locale in schedule (Tier 1 every cycle, Tier 2 monthly, Tier 3 quarterly):

```bash
# Locales use Apple's locale format:
# us → en-US, gb → en-GB, de → de-DE, ja → ja-JP, fr → fr-FR
# es → es-ES, mx → es-MX, br → pt-BR, it → it-IT, nl → nl-NL
# ko → ko-KR, zh → zh-Hans, tw → zh-Hant, tr → tr-TR, ru → ru-RU

LOCALE_MAP=(
  "us:en-US" "gb:en-GB" "au:en-AU" "ca:en-CA"
  "de:de-DE" "at:de-AT" "ch:de-CH"
  "fr:fr-FR" "es:es-ES" "mx:es-MX"
  "br:pt-BR" "pt:pt-PT"
  "it:it-IT" "nl:nl-NL"
  "ja:ja-JP" "ko:ko-KR"
  "zh:zh-Hans" "tw:zh-Hant"
  "tr:tr-TR" "ru:ru-RU"
)
```

---

## Step 2.4 — Push Description Updates (Version-Level)

For full description updates, use version-level CLI commands:

```bash
# Get current version ID first
asc apps versions list --app-id $APP_ID --filter-version-string <CURRENT_VERSION>

# Update description
asc apps versions update \
  --app-id $APP_ID \
  --locale en-US \
  --description "$(cat ./aso-data/metadata/us_description.txt)"
```

Description writing guidelines:
- **First 3 lines** visible in App Store preview — pack highest-priority keywords here
- Use natural language — Apple's algorithm reads for context, not just exact match
- Structure: Hook (3 lines) → Core features → Social proof → Call to action
- Mirror keyword field terms organically throughout

---

## Step 2.5 — Add New Keywords to Astro Tracking

After pushing to ASC, track ALL new keywords in Astro so rank monitoring begins immediately.

```
Use Astro MCP:

For each locale and each new keyword that was added to the keyword field:
- Call add_keyword (or equivalent Astro MCP tracking tool)
- Confirm keyword appears in get_app_keywords response

This is critical — Astro tracks rank changes over time.
Missing this step means lost data for Phase 3 comparisons.
```

---

## Step 2.6 — Save Change Log

```bash
cat > $CHANGELOG << 'EOF'
{
  "date": "YYYY-MM-DD",
  "changes": [
    {
      "locale": "us",
      "apple_locale": "en-US",
      "field": "keywords",
      "before": "old,keywords,here",
      "after": "new,optimized,keywords",
      "char_count_before": 85,
      "char_count_after": 97,
      "new_keywords_added_to_astro": ["reflection", "gratitude", "mindfulness"],
      "keywords_removed": ["oldkeyword1", "oldkeyword2"],
      "pushed_at": "YYYY-MM-DDTHH:MM:SSZ"
    },
    {
      "locale": "us",
      "apple_locale": "en-US",
      "field": "subtitle",
      "before": "Old Subtitle Here",
      "after": "Mood Tracker & Memory Keeper",
      "pushed_at": "YYYY-MM-DDTHH:MM:SSZ"
    }
  ]
}
EOF
```

---

## Completion Checklist

- [ ] All current metadata backed up to `./aso-data/backup/{locale}_metadata_before_{date}.json`
- [ ] Keyword fields updated for all scheduled locales
- [ ] Subtitle updated for all scheduled locales
- [ ] Description updated if new version submitted (optional this cycle)
- [ ] All new keywords added to Astro tracking
- [ ] `./aso-data/changelog/metadata_changes_{date}.json` saved
- [ ] Character counts verified (keywords ≤ 100, subtitle ≤ 30)
- [ ] No duplicates across title + subtitle + keyword field

**→ Proceed to Phase 3 daily monitoring. Changes take effect within 24–72 hours.**
