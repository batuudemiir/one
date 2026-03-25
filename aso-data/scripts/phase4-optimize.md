# Phase 4: Optimize — Data-Driven Iteration

**Run:** Weekly (scoring) + Bi-weekly (rotation) + Monthly (locale retier)
**Requires:** 7+ days of Astro rank data, weekly report complete
**Output:** `./aso-data/scores/keyword_scores_{YYYY-MM-DD}.json`

---

## Step 4.1 — Keyword Performance Scoring

**Run:** Every week (after Phase 3.2 weekly report)

### Scoring Formula

```
SCORE = (popularity × 0.4) + ((100 - difficulty) × 0.3) + (rank_improvement × 0.3)

Where rank_improvement:
  = 0                          if no rank (not yet ranking)
  = (previous_rank - current_rank) / previous_rank × 100   if has rank data (7d delta)
  = -20                        if rank declined this week
  = +20 bonus                  if entered top 10
  = +30 bonus                  if at rank 1–3
```

### Prompt to Run

```
Use Astro MCP:

1. Call get_app_keywords — get ALL tracked keywords with current and 7d-ago ranks.
2. For each keyword, compute SCORE using:
   SCORE = (popularity × 0.4) + ((100 - difficulty) × 0.3) + (rank_improvement × 0.3)

3. Categorize each keyword:
   - WINNER: score > 70 AND rank improved this week → Keep, protect, consider moving to subtitle
   - POTENTIAL: score > 50 AND rank stagnant (< 3 positions change) → Monitor, optimize placement
   - UNDERPERFORMER: score < 30 AND no rank after 14 days → Flag for replacement
   - DECLINING: rank worsened > 5 positions → Investigate (competitor moved up?)
   - NEW_OPPORTUNITY: not tracked, found in competitor research → Add next cycle

4. Save output to: ./aso-data/scores/keyword_scores_{YYYY-MM-DD}.json
```

### Output Format

```json
{
  "date": "YYYY-MM-DD",
  "app_id": "...",
  "summary": {
    "total_scored": 120,
    "winners": 18,
    "potential": 34,
    "underperformers": 22,
    "declining": 8,
    "new_opportunities": 15
  },
  "keywords": [
    {
      "keyword": "daily journal",
      "locale": "us",
      "popularity": 72,
      "difficulty": 38,
      "current_rank": 11,
      "previous_rank": 18,
      "rank_improvement": 38.9,
      "score": 83.2,
      "category": "WINNER",
      "in_title": false,
      "in_subtitle": false,
      "in_keyword_field": true,
      "recommendation": "Consider moving to subtitle — high score, improving fast"
    },
    {
      "keyword": "old keyword",
      "locale": "us",
      "popularity": 22,
      "difficulty": 55,
      "current_rank": null,
      "previous_rank": null,
      "rank_improvement": 0,
      "score": 21.3,
      "category": "UNDERPERFORMER",
      "days_tracked": 18,
      "in_keyword_field": true,
      "recommendation": "Replace — no ranking after 18 days"
    }
  ]
}
```

---

## Step 4.2 — Metadata Rotation Strategy

**Run:** Bi-weekly (every 2 weeks, same day as Phase 1 + Phase 2)

### Process

```
1. Load ./aso-data/scores/keyword_scores_{latest}.json
2. Load ./aso-data/research/{locale}_recommended_keywords_{latest}.json for each locale

3. For each locale's keyword field (100 chars max):
   a. KEEP all WINNER keywords (score > 70)
   b. KEEP all POTENTIAL keywords if space allows (score > 50)
   c. REPLACE UNDERPERFORMER keywords (score < 30, 14+ days) with NEW_OPPORTUNITY keywords
   d. If new opportunities exceed space: rank by (popularity DESC, difficulty ASC)

4. For subtitle:
   - If WINNER keyword is not in title and not in subtitle → consider adding to subtitle
   - Rotate subtitle every version update (A/B test variants)
   - Variant A: feature-focused ("Mood Tracker & Memory Keeper")
   - Variant B: benefit-focused ("Remember Every Moment")
   - Track which subtitle correlates with better conversion (Mixpanel install→trial)

5. Build new keyword string for each locale:
   - Verify: no duplicates with title words, no duplicates with subtitle words
   - Verify: total char count ≤ 100
   - Verify: no spaces after commas
   - Verify: no app name, no category name

6. Run Phase 2 to push changes.
7. Log all changes in changelog.
```

### Rotation Decision Matrix

| Category | Action |
|---|---|
| WINNER (score > 70, improving) | Keep in keyword field. If not in subtitle → consider moving up |
| POTENTIAL (score > 50, stagnant) | Keep for 1 more cycle. If still stagnant → rotate to subtitle/title |
| UNDERPERFORMER (score < 30, 14+ days) | Replace immediately with best available NEW_OPPORTUNITY |
| DECLINING (worsened > 5 positions) | Investigate first — is a competitor now outranking? If yes, find alternative |
| NEW_OPPORTUNITY (competitor has it, I don't) | Add to keyword field next rotation |

---

## Step 4.3 — Locale Prioritization (Monthly Retier)

**Run:** Monthly

### Prompt

```
Use RevenueCat MCP:

1. Call get_revenue with breakdown by country for the past 30 days.
2. Compute each country's % of total revenue.
3. Map country → locale code (using config/locales.json).
4. Retier locales:
   - TIER 1 (>10% of revenue): Full optimization every bi-weekly cycle
   - TIER 2 (2–10% of revenue): Optimize monthly (every other cycle)
   - TIER 3 (<2% of revenue): Quarterly optimization only

5. Update config/locales.json with new tier values.
6. Save retier report to: ./aso-data/reports/locale_retier_{YYYY-MM-DD}.md
```

### Retier Report Format

```markdown
# Locale Retier Report — {YYYY-MM-DD}

## Revenue by Country (Last 30 Days)

| Locale | Country | Revenue | % of Total | New Tier | Old Tier | Change |
|---|---|---|---|---|---|---|
| us | United States | $X | 45% | 1 | 1 | — |
| de | Germany | $X | 12% | 1 | 2 | ↑ PROMOTED |
| gb | United Kingdom | $X | 9% | 2 | 1 | ↓ DEMOTED |

## Tier Changes This Month
- Promoted to Tier 1: [locales]
- Demoted from Tier 1: [locales]
- Promoted to Tier 2: [locales]
- Demoted to Tier 3: [locales]

## Updated Optimization Schedule
- Bi-weekly (Tier 1): [locale list]
- Monthly (Tier 2): [locale list]
- Quarterly (Tier 3): [locale list]
```

---

## Completion Checklist (Weekly Scoring)
- [ ] `./aso-data/scores/keyword_scores_{date}.json` saved
- [ ] UNDERPERFORMER list reviewed — replacements identified from latest research
- [ ] WINNER list reviewed — any should be promoted to subtitle?
- [ ] Decision documented: rotate this cycle or hold?

## Completion Checklist (Bi-Weekly Rotation)
- [ ] New keyword strings built for all Tier 1 locales
- [ ] Character counts verified
- [ ] Duplicate check passed
- [ ] Phase 2 executed (metadata pushed)
- [ ] Changelog updated

## Completion Checklist (Monthly Retier)
- [ ] Revenue data pulled from RevenueCat
- [ ] `config/locales.json` tier values updated
- [ ] `./aso-data/reports/locale_retier_{date}.md` saved
- [ ] Optimization schedule updated
