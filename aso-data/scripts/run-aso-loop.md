# ASO Growth Loop — Main Orchestrator

**App:** ONE (com.batu.ones)
**Goal:** Reach target MRR through 100% organic App Store growth
**Method:** Iterative ASO using Astro MCP + ASC CLI + Mixpanel MCP + RevenueCat MCP

---

## Phase 0: Environment Verification (Run Once)

Before starting any loop iteration, verify all tools are connected:

```
1. Use Astro MCP → call list_apps
   Expected: returns ONE app with ID and keyword count
   If empty: Open Astro macOS app first, ensure sync is complete

2. Use Mixpanel MCP → query today's active users (event: app_opened)
   Expected: returns numeric DAU value
   If fails: check MIXPANEL_TOKEN and MIXPANEL_API_SECRET env vars

3. Use RevenueCat MCP → call get_overview
   Expected: returns MRR and active subscriber count
   If fails: check REVENUECAT_API_KEY env var

All three must return data before proceeding.
```

```bash
# Verify ASC CLI
asc apps list
# Expected: shows ONE app in App Store Connect
```

---

## Daily Routine (Run Every Morning)

```
TODAY = $(date +%Y-%m-%d)

1. Run Phase 3.1 daily report
   → Prompt file: ./aso-data/scripts/phase3-daily-report.md
   → Output: ./aso-data/reports/daily_report_{TODAY}.md

2. Review anomalies section:
   → Any keyword drops > 10 positions? Investigate competitors
   → Organic installs dropped > 30%? Check which keywords lost rank
   → MRR dropped? Check churn by locale

3. No action needed unless anomalies flagged.
```

---

## Weekly Routine (Every 7 Days)

```
WEEK_DATE = $(date +%Y-%m-%d)

1. Run Phase 3.2 weekly comparison report
   → Prompt file: ./aso-data/scripts/phase3-weekly-report.md
   → Output: ./aso-data/reports/weekly_comparison_{WEEK_DATE}.md

2. Run Phase 4.1 keyword scoring
   → Prompt file: ./aso-data/scripts/phase4-optimize.md (Section 4.1)
   → Output: ./aso-data/scores/keyword_scores_{WEEK_DATE}.json

3. Decision gate:
   IF any keyword scored UNDERPERFORMER (score < 30, 14+ days tracked):
     → Schedule keyword rotation for bi-weekly cycle
   IF WINNER keywords are not in subtitle:
     → Flag for subtitle A/B test next version update
   ELSE:
     → Hold current metadata, continue monitoring
```

---

## Bi-Weekly Routine (Every 14 Days)

```
CYCLE_DATE = $(date +%Y-%m-%d)

1. Run Phase 1: Full ASO Research
   → Prompt file: ./aso-data/scripts/phase1-research.md
   → Covers: Tier 1 locales (every cycle) + Tier 2 (if monthly cycle aligns)
   → Outputs: ./aso-data/baseline/ and ./aso-data/research/

2. Run Phase 4.2: Metadata Rotation Decision
   → Prompt file: ./aso-data/scripts/phase4-optimize.md (Section 4.2)
   → Build new keyword strings per locale
   → Verify char counts, no duplicates

3. Run Phase 2: Push to App Store Connect
   → Prompt file: ./aso-data/scripts/phase2-implement.md
   → Backup first, then push keyword + subtitle updates
   → Add new keywords to Astro tracking

4. Log all changes:
   → ./aso-data/changelog/metadata_changes_{CYCLE_DATE}.json
```

---

## Monthly Routine

```
MONTH_DATE = $(date +%Y-%m-%d)

1. Run Phase 4.3: Locale Retier
   → Prompt file: ./aso-data/scripts/phase4-optimize.md (Section 4.3)
   → Pull RevenueCat revenue by country (last 30 days)
   → Update config/locales.json tier values
   → Output: ./aso-data/reports/locale_retier_{MONTH_DATE}.md

2. Full competitor re-analysis
   → Re-run Phase 1.3 for ALL tier 1 locales
   → Update config/competitors.json

3. Strategic review:
   → Is organic-only working? (MRR trend positive?)
   → Any locales showing high installs but low revenue? (paywall review)
   → Any product changes needed based on D1/D7/D30 retention trends?
```

---

## Exit Condition Check (Weekly)

```
Load current MRR from ./aso-data/reports/daily_report_{TODAY}.md
Load target MRR from ./aso-data/config/targets.json

IF current_mrr >= target_mrr:
  → Generate final report (see below)
  → EXIT LOOP
ELSE:
  → Continue loop
  → Note progress: current $X of target $Xk (X% complete)
```

---

## Final Report (When Target Reached)

```markdown
# ASO Growth Loop — COMPLETE

**Date achieved:** {YYYY-MM-DD}
**Total time:** X weeks/months
**Final MRR:** $X
**Target MRR:** $X

## What Worked
- Top 3 keywords by install volume
- Top 3 locales by revenue
- Most impactful metadata changes

## Key Metrics Journey
| Week | MRR | Active Subs | Top Keyword Rank |
|---|---|---|---|

## Archive
All data preserved in ./aso-data/ for future reference.
```

---

## File Index

| File | Purpose | Updated |
|---|---|---|
| `config/locales.json` | Active locale list with tiers | Monthly |
| `config/targets.json` | MRR target, scoring weights, seed keywords | As needed |
| `config/competitors.json` | Tracked competitor app IDs per locale | Monthly |
| `baseline/current_keywords_{date}.json` | Snapshot of all tracked keywords | Bi-weekly |
| `research/{locale}_keyword_opportunities_{date}.json` | Keyword research output | Bi-weekly |
| `research/{locale}_competitor_analysis_{date}.json` | Competitor keyword gaps | Bi-weekly |
| `research/{locale}_recommended_keywords_{date}.json` | Final recommended list | Bi-weekly |
| `reports/daily_report_{date}.md` | Daily ASO + analytics + revenue | Daily |
| `reports/weekly_comparison_{date}.md` | Week-over-week comparison | Weekly |
| `reports/locale_retier_{date}.md` | Locale tier changes | Monthly |
| `scores/keyword_scores_{date}.json` | Scored keyword performance | Weekly |
| `changelog/metadata_changes_{date}.json` | Record of all ASO pushes | Per push |
| `backup/{locale}_metadata_before_{date}.json` | Pre-push metadata backup | Per push |

---

## MCP Quick Reference

| Task | Tool | Command |
|---|---|---|
| List tracked apps | Astro MCP | `list_apps` |
| Get keywords + ranks | Astro MCP | `get_app_keywords` |
| Search keyword rankings | Astro MCP | `search_rankings` |
| Historical rank data | Astro MCP | `get_historical_rankings` |
| Daily active users | Mixpanel MCP | `query_events` |
| Conversion funnel | Mixpanel MCP | `query_funnel` |
| Retention cohorts | Mixpanel MCP | `query_retention` |
| Current MRR | RevenueCat MCP | `get_overview` |
| Revenue by country | RevenueCat MCP | `get_revenue` |
| Push keywords | ASC CLI | `asc apps info update --keywords` |
| Push subtitle | ASC CLI | `asc apps info update --subtitle` |
| Backup metadata | ASC CLI | `asc apps info get` |

---

## Critical Rules (Never Violate)

1. **Always backup before pushing.** ASC metadata changes are immediate and hard to revert.
2. **Never skip saving outputs.** Every data point is needed for future comparisons.
3. **Keep Astro macOS app running and synced.** It reads from local SQLite — no sync = stale data.
4. **Keyword field: no spaces after commas.** `word1,word2,word3` not `word1, word2, word3`
5. **Never repeat a word** across title + subtitle + keyword field. Apple deduplicates — it wastes a slot.
6. **Always use singular forms.** Apple auto-matches plural.
7. **Title changes require a new binary.** Only change title with planned version releases.
