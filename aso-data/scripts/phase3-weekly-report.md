# Phase 3.2: Weekly Comparison Report

**Run:** Every 7 days (end of week)
**Requires:** Astro MCP + Mixpanel MCP + RevenueCat MCP + 7 daily reports in hand
**Output:** `./aso-data/reports/weekly_comparison_{YYYY-MM-DD}.md`

---

## Prompt to Run Weekly

```
Today is {YYYY-MM-DD}. Generate my weekly ASO comparison report.

## SECTION 1: Keyword Rankings Delta (Astro MCP)

1. Call get_historical_rankings for the past 14 days (this week vs last week).
2. For ALL tracked keywords, compute:
   - This week avg rank vs last week avg rank
   - Total keywords improved
   - Total keywords declined
   - Keywords that entered top 10 this week (were not in top 10 last week)
   - Keywords that dropped out of top 50 this week
   - Keywords that held rank 1–3 all week (stable prime positions)

## SECTION 2: Install ↔ Keyword Correlation (Astro + Mixpanel)

Cross-reference:
- Which keywords improved this week? → Did installs from those locales increase?
  (e.g., if "daily journal" improved in DE, did German installs go up?)
- Which locales saw the biggest install growth? → What metadata changed there?
- Identify: correlation between metadata changes (from changelog) and install changes

## SECTION 3: Revenue Impact (RevenueCat MCP)

1. MRR this week vs last week vs 4 weeks ago
2. Revenue by country — which locales grew, which declined?
3. Organic install → trial → paid funnel efficiency (this week vs last week):
   - Install-to-trial rate
   - Trial-to-paid rate
   - Overall install-to-paid rate
4. Subscriber LTV estimate (MRR / active subscribers)

## SECTION 4: Cohort Analysis (Mixpanel MCP)

For users who installed this week vs last week:
- D1 retention comparison
- Onboarding completion comparison
- Trial start rate comparison
```

---

## Output Template

```markdown
# Weekly ASO Comparison — Week of {YYYY-MM-DD}

## Keyword Rankings Delta

**Total keywords tracked:** X
**This week avg rank:** X.X
**Last week avg rank:** X.X
**Net change:** +/- X.X positions

### Improved This Week
| Keyword | Last Week | This Week | Delta | Locale |
|---|---|---|---|---|
| daily journal | 18 | 11 | ↑ 7 | us |

### Declined This Week
| Keyword | Last Week | This Week | Delta | Locale |
|---|---|---|---|---|

### Entered Top 10 (New!)
- keyword (now rank X in locale XX)

### Dropped Out of Top 50
- keyword (was rank X in locale XX)

### Stable Prime Positions (Rank 1–3 all week)
- keyword: rank X (locale XX) — protect this!

---

## Install ↔ Keyword Correlation

### Locales with increased installs this week
| Locale | Install change | Keywords that improved |
|---|---|---|
| us | ↑ 23% | daily journal (↑7), memory keeper (↑12) |

### Locales with decreased installs
| Locale | Install change | Possible cause |
|---|---|---|

### Metadata Change Impact
Changes pushed on {date}:
- en-US subtitle update → installs ↑/↓ X%
- de-DE keyword update → installs ↑/↓ X%

---

## Revenue Impact

| Period | MRR | Change |
|---|---|---|
| This week | $X | +$X vs last week |
| Last week | $X | +$X vs week before |
| 4 weeks ago | $X | baseline |

**Organic funnel this week vs last week:**
| Stage | This Week | Last Week | Change |
|---|---|---|---|
| Install-to-trial | X% | X% | ↑/↓ |
| Trial-to-paid | X% | X% | ↑/↓ |
| Install-to-paid | X% | X% | ↑/↓ |

**Top Revenue Locales This Week:**
1. US — $X (↑/↓ X% vs last week)
2. DE — $X (↑/↓ X%)
3. GB — $X (↑/↓ X%)

**Subscriber LTV:** $X/month avg

---

## Cohort Comparison

| Metric | This Week Cohort | Last Week Cohort |
|---|---|---|
| D1 retention | X% | X% |
| Onboarding completion | X% | X% |
| Trial start rate | X% | X% |

---

## Action Items for Next Week

Based on this week's data:

### Keywords to Double Down On (improving + high potential)
- keyword (locale) — priority: high
  → Move to subtitle or optimize position in keyword field

### Keywords to Replace (no movement after 2+ weeks)
- keyword (locale) — replace with: [alternative from research]

### Locales to Re-Optimize (declining installs despite keyword stability)
- locale — suspected issue: [title? subtitle? description? screenshot?]

### Metadata Changes to Test Next Cycle
- [ ] Test subtitle variation A vs B (us)
- [ ] Add competitor gap keywords to keyword field (de)
- [ ] Refresh description first 3 lines (ja)

### Revenue Opportunities
- locale showing high installs but low conversion → paywall review needed
```

---

## Completion Checklist

- [ ] `./aso-data/reports/weekly_comparison_{date}.md` saved
- [ ] Action items captured and prioritized
- [ ] Keyword scoring ready to run (see Phase 4.1)
- [ ] Decision made: rotate keywords this cycle or hold?
