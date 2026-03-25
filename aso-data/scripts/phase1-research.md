# Phase 1: Full ASO Research — Prompt Script

**Run:** Bi-weekly (every 2 weeks)
**Requires:** Astro MCP connected and synced
**Output directory:** `./aso-data/research/` and `./aso-data/baseline/`

---

## Step 1.1 — Get Current App State

```
Use Astro MCP:

1. Call list_apps
   → Record: app_id, app_name, platform, total_keywords_tracked

2. Call get_app_keywords for app_id = [YOUR_APP_ID]
   → Export ALL keywords with fields:
     - keyword
     - current_rank
     - previous_rank
     - popularity (0–100)
     - difficulty (0–100)
     - rank_change (current_rank - previous_rank, negative = improved)

3. Save result to:
   ./aso-data/baseline/current_keywords_{YYYY-MM-DD}.json

   Format:
   {
     "date": "YYYY-MM-DD",
     "app_id": "...",
     "total_tracked": N,
     "keywords": [
       {
         "keyword": "daily journal",
         "current_rank": 12,
         "previous_rank": 18,
         "rank_change": -6,
         "popularity": 62,
         "difficulty": 44
       }
     ]
   }
```

---

## Step 1.2 — Keyword Research for Tier 1 Locales (Every Cycle)

**Tier 1 locales:** us, gb, de, ja
*(Full list in config/locales.json — check tier field)*

For EACH Tier 1 locale:

```
Use Astro MCP search_rankings:

Prompt template (repeat for each locale):
"Search App Store rankings in the [LOCALE] store for keywords related to:
 daily journal, mood tracker, personal diary, life log, memory keeper,
 daily planner, gratitude journal, habit tracker, reflection app.

 Return top 50 keywords where:
 - popularity >= 20
 - difficulty < 60

 Sort by: popularity DESC"

Save to: ./aso-data/research/{locale}_keyword_opportunities_{YYYY-MM-DD}.json

Format:
{
  "locale": "us",
  "date": "YYYY-MM-DD",
  "app_id": "...",
  "opportunities": [
    {
      "keyword": "daily journal",
      "popularity": 72,
      "difficulty": 38,
      "current_rank": null,
      "priority": "high"
    }
  ]
}
```

**Priority rules:**
- `high`: popularity >= 50 AND difficulty < 40
- `medium`: popularity >= 30 AND difficulty < 60
- `low`: everything else that still meets minimum thresholds

---

## Step 1.2b — Keyword Research for Tier 2/3 Locales (Per Schedule)

**Tier 2 locales (monthly):** gb, au, ca, fr, es, mx, br, it, nl, ko, zh, tw, tr, ru
**Tier 3 locales (quarterly):** at, ch, pt, ar, sv, no, da, fi, th, id, ms, vi, pl, cs, ro, hu, uk

Same process as 1.2 above, using locale-appropriate seed keywords from `config/targets.json` → `core_category_keywords`.

---

## Step 1.3 — Competitor Analysis per Locale

For each locale being researched this cycle:

```
Use Astro MCP search_rankings:

"In the [LOCALE] App Store, search for apps ranking in the top 10 for:
 [top 3 keywords from 1.2 results for this locale]

 Return the top 5 apps (by ranking consistency across keywords).
 For each competitor app:
 - app_id
 - app_name
 - get_app_keywords → export their full keyword set

 Then identify: keywords they rank top-20 for that I am NOT currently tracking."

Save to: ./aso-data/research/{locale}_competitor_analysis_{YYYY-MM-DD}.json

Format:
{
  "locale": "us",
  "date": "YYYY-MM-DD",
  "competitors": [
    {
      "app_id": "...",
      "app_name": "Day One",
      "top_keywords": [
        {
          "keyword": "journal app",
          "their_rank": 2,
          "my_rank": null,
          "popularity": 68,
          "difficulty": 45,
          "opportunity": true
        }
      ]
    }
  ],
  "gap_keywords": [
    {
      "keyword": "memory journal",
      "best_competitor_rank": 3,
      "popularity": 55,
      "difficulty": 32,
      "currently_tracked": false
    }
  ]
}
```

Update `./aso-data/config/competitors.json` with discovered competitor app IDs.

---

## Step 1.4 — Build Recommended Keyword List per Locale

Merge opportunities (1.2) + gap keywords (1.3) and deduplicate.

```
For each locale, produce:
./aso-data/research/{locale}_recommended_keywords_{YYYY-MM-DD}.json

Format:
{
  "locale": "us",
  "date": "YYYY-MM-DD",
  "recommended": [
    {
      "keyword": "daily journal",
      "popularity": 72,
      "difficulty": 38,
      "source": "opportunity",
      "priority": "high",
      "currently_tracked": true,
      "current_rank": 12,
      "action": "keep"
    },
    {
      "keyword": "memory journal",
      "popularity": 55,
      "difficulty": 32,
      "source": "competitor_gap",
      "priority": "high",
      "currently_tracked": false,
      "current_rank": null,
      "action": "add"
    }
  ]
}
```

**Action values:**
- `keep` — already tracked, performing well
- `add` — new opportunity, not yet tracked
- `replace_candidate` — low-performing keyword that could be swapped out
- `monitor` — not enough data yet, watch for 7+ days

---

## Completion Checklist

- [ ] `./aso-data/baseline/current_keywords_{date}.json` saved
- [ ] `./aso-data/research/{locale}_keyword_opportunities_{date}.json` saved for all scheduled locales
- [ ] `./aso-data/research/{locale}_competitor_analysis_{date}.json` saved for all scheduled locales
- [ ] `./aso-data/research/{locale}_recommended_keywords_{date}.json` saved for all scheduled locales
- [ ] `./aso-data/config/competitors.json` updated with any new competitor IDs

**→ Proceed to Phase 2 when complete.**
