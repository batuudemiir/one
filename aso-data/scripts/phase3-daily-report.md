# Phase 3.1: Daily Report — ASO + Analytics + Revenue

**Run:** Every morning
**Requires:** Astro MCP + Mixpanel MCP + RevenueCat MCP all connected
**Output:** `./aso-data/reports/daily_report_{YYYY-MM-DD}.md`

---

## Prompt to Run Each Morning

Copy and run the following as a single Claude session:

---

```
Today is {YYYY-MM-DD}. Generate my daily ASO growth loop report.

## SECTION 1: ASO Performance (Astro MCP)

1. Call get_app_keywords for my app.
   Return ALL tracked keywords with: keyword, current_rank, previous_rank, rank_change, popularity, difficulty.

2. Call get_historical_rankings to compare today vs 7 days ago.
   Return: keywords that improved, declined, newly entered top 50, dropped out of top 50.

3. Compute:
   - Total keywords tracked
   - Keywords improved (rank_change < 0, i.e. moved up)
   - Keywords declined (rank_change > 0, i.e. moved down)
   - Average rank change across all keywords
   - Keywords entering top 10 for first time
   - Keywords at rank 1–3 (prime positions)

## SECTION 2: User Analytics (Mixpanel MCP)

Query Mixpanel for today vs 7-day average:

1. DAU — Daily Active Users (event: app_opened or session_start)
2. New organic installs (event: first_open or install, source: organic)
3. Onboarding completion rate (event: onboarding_completed / first_open)
4. Trial started (event: trial_started)
5. Subscription started (event: subscription_started)
6. Retention: D1, D7, D30 cohort rates (most recent available)

Compute trend: today vs 7-day avg as percentage change.

## SECTION 3: Revenue (RevenueCat MCP)

1. Call get_overview — current MRR, active subscribers
2. MRR delta: today vs 7 days ago vs 30 days ago
3. Trial → paid conversion rate (trials started last 30 days → converted)
4. Churn rate (subscribers lost this week / total active last week)
5. Revenue by country/locale (top 10 countries by revenue)
6. New paying subscribers today

## OUTPUT FORMAT

Save result as: ./aso-data/reports/daily_report_{YYYY-MM-DD}.md

Use this template exactly:
```

---

## Output Template

```markdown
# Daily ASO Report — {YYYY-MM-DD}

## ASO Performance (Astro)

**Keywords tracked:** X
**Average rank change (7d):** +/- N positions

### Improved Rankings
| Keyword | 7d Ago | Today | Change |
|---|---|---|---|
| daily journal | 18 | 12 | ↑ 6 |

### Declined Rankings
| Keyword | 7d Ago | Today | Change |
|---|---|---|---|
| mood app | 5 | 9 | ↓ 4 |

### New Top-50 Entries
- keyword_name (rank: X)

### Lost Rankings (Dropped out of top 50)
- keyword_name (was rank X)

### Prime Positions (Rank 1–3)
- keyword_name: rank X (locale: XX)

---

## User Analytics (Mixpanel)

| Metric | Today | 7d Avg | Trend |
|---|---|---|---|
| DAU | X | X | ↑/↓ Y% |
| Organic installs | X | X | ↑/↓ Y% |
| Onboarding completion | X% | X% | ↑/↓ |
| Trial started | X | X | ↑/↓ Y% |
| Subscription started | X | X | ↑/↓ Y% |

**Retention:**
- D1: X%
- D7: X%
- D30: X%

---

## Revenue (RevenueCat)

| Metric | Value |
|---|---|
| MRR | $X |
| MRR (7d ago) | $X |
| MRR (30d ago) | $X |
| MRR growth (7d) | +$X |
| Active subscribers | X |
| Trial → paid conversion | X% |
| Churn rate (weekly) | X% |
| New paying subscribers today | X |

**Top Revenue Locales:**
1. US — $X (X%)
2. DE — $X (X%)
3. GB — $X (X%)
...

---

## Anomalies & Flags

> List any unusual changes that need investigation:
> - Sudden rank drop > 10 positions (possible competitor surge or algo update)
> - Install spike or drop > 30% vs 7d avg
> - MRR drop > 5% week-over-week
> - Churn spike

---

## Action Items

> Based on today's data:
> - [ ] Item 1
> - [ ] Item 2
```

---

## Anomaly Detection Rules

Flag the following for manual review:

| Condition | Flag |
|---|---|
| Any keyword drops > 10 positions in one day | 🚨 COMPETITOR SURGE or ALGO UPDATE |
| Organic installs drop > 30% vs 7d avg | 🚨 RANKING LOSS — check top keywords |
| MRR drops > 5% week-over-week | 🚨 CHURN EVENT — check churned subscriber locales |
| Churn rate > 8% weekly | 🚨 PRODUCT ISSUE — check reviews |
| D1 retention < 30% | 🚨 ONBOARDING PROBLEM |
| Trial conversion < 5% | 🚨 PAYWALL ISSUE |
| Any keyword enters rank 1–3 | ✅ CELEBRATE + PROTECT |
| New keywords enter top 10 (newly added) | ✅ METADATA WORKING |

---

## Completion Checklist

- [ ] `./aso-data/reports/daily_report_{date}.md` saved
- [ ] Anomalies noted and flagged for follow-up
- [ ] Action items recorded
