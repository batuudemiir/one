ASO Growth Loop — Claude Code Execution Plan

Goal: Reach $Xk MRR through 100% organic App Store growth. Method: Iterative ASO optimization using Astro MCP + ASC CLI + Mixpanel MCP + RevenueCat MCP. Loop: Research → Implement → Measure → Compare → Optimize → Repeat.
Phase 0: Environment Setup
0.1 — Install & Connect Astro MCP

claude mcp add -s user -t stdio astro -- npx -y astro-mcp-server

Verify connection:

Use Astro MCP to list all tracked apps.

Expected: Returns app list with IDs, platforms, keyword counts. If empty: Open Astro macOS app first, ensure it has synced data.
0.2 — Install ASC CLI (App Store Connect)
# If not installed
brew install apple/apple/asc-cli

# Authenticate — requires API key from App Store Connect
asc auth login --issuer-id <ISSUER_ID> --key-id <KEY_ID> --key <PATH_TO_P8>

Verify: asc apps list should return your app(s).
0.3 — Connect Mixpanel MCP
claude mcp add -s user -t stdio mixpanel -- npx -y @anthropic/mixpanel-mcp-server
Or add to claude_desktop_config.json:

{
  "mcpServers": {
    "mixpanel": {
      "command": "npx",
      "args": ["-y", "@anthropic/mixpanel-mcp-server"],
      "env": {
        "MIXPANEL_TOKEN": "<YOUR_TOKEN>",
        "MIXPANEL_API_SECRET": "<YOUR_SECRET>"
      }
    }
  }
}
0.4 — Connect RevenueCat MCP

claude mcp add -s user -t stdio revenuecat -- npx -y @anthropic/revenuecat-mcp-server

Or config:
{
  "mcpServers": {
    "revenuecat": {
      "command": "npx",
      "args": ["-y", "@anthropic/revenuecat-mcp-server"],
      "env": {
        "REVENUECAT_API_KEY": "<YOUR_V1_API_KEY>"
      }
    }
  }
}
0.5 — Verify All Connections

Run this as a smoke test:
List my apps from Astro.
Show today's active users from Mixpanel.
Show current MRR from RevenueCat.
All three must return data before proceeding.

Phase 1: Full ASO Research (All Locales)

1.1 — Get Current App State

Use Astro MCP:
1. list_apps — get my app ID and current keyword count
2. get_app_keywords for my app — export ALL current keywords with:
   - current rank
   - previous rank
   - popularity score
   - difficulty score
   - rank change
Save output to: ./aso-data/baseline/current_keywords_{date}.json
1.2 — Research Keywords for ALL Supported Locales

Apple App Store supports these primary locales. Run keyword research for EACH:
LOCALES = [
  "us", "gb", "au", "ca",        # English
  "de", "at", "ch",              # German
  "fr",                          # French
  "es", "mx",                    # Spanish
  "pt", "br",                    # Portuguese
  "it",                          # Italian
  "nl",                          # Dutch
  "ja",                          # Japanese
  "ko",                          # Korean
  "zh",                          # Chinese (Simplified)
  "tw",                          # Chinese (Traditional)
  "tr",                          # Turkish
  "ru",                          # Russian
  "ar",                          # Arabic
  "sv", "no", "da", "fi",        # Nordic
  "th", "id", "ms", "vi",        # Southeast Asian
  "pl", "cs", "ro", "hu", "uk"   # Eastern European
]
For EACH locale, run:
Use Astro MCP search_rankings:
- Query: [your app's core category keywords]
- Store: {locale}
- Find: top 50 keywords by popularity where difficulty < 60
1.3 — Competitor Analysis per Locale
For each locale, identify top 5 competitors:
Use Astro MCP search_rankings:
- Find apps ranking for my target keywords
- For each competitor: get_app_keywords to see their full keyword set
- Identify keywords they rank for that I don't track
1.4 — Save All Research Output
Directory structure:
./aso-data/
├── baseline/
│   └── current_keywords_{date}.json
├── research/
│   ├── {locale}_keyword_opportunities_{date}.json
│   ├── {locale}_competitor_analysis_{date}.json
│   └── {locale}_recommended_keywords_{date}.json
├── reports/
│   └── daily_report_{date}.md
└── changelog/
    └── metadata_changes_{date}.json
Save format per locale:
{
  "locale": "us",
  "date": "2026-03-25",
  "app_id": "...",
  "opportunities": [
    {
      "keyword": "...",
      "popularity": 45,
      "difficulty": 22,
      "current_rank": null,
      "competitor_ranks": { "competitor_app_id": 3 },
      "priority": "high"
    }
  ]
}
Phase 2: Implement — Push to App Store Connect
2.1 — Build Optimized Metadata per Locale
For EACH locale, construct:

Field Max Length Strategy     Title 30 chars Brand + #1 keyword   Subtitle 30 chars #2 and #3 keywords, natural phrasing   Keyword field 100 chars Remaining keywords, comma-separated, no spaces   Description 4000 chars Keyword-rich but readable, first 3 lines critical

Rules:
No duplicate words across title + subtitle + keyword field (Apple deduplicates)
Keyword field: no spaces after commas, no app name, no category name

Prioritize: high popularity + low difficulty keywords first
Use singular forms (Apple matches plural automatically)
2.2 — Push Metadata via ASC CLI
# Download current metadata
asc apps info get --app-id <APP_ID> --locale <LOCALE> > ./aso-data/backup/{locale}_metadata_before.json

# Update keyword field
asc apps info update --app-id <APP_ID> --locale <LOCALE> \
  --keywords "keyword1,keyword2,keyword3,..."

# Update subtitle
asc apps info update --app-id <APP_ID> --locale <LOCALE> \
  --subtitle "New Optimized Subtitle"

# For description updates: use the version-level update
asc apps versions update --app-id <APP_ID> --locale <LOCALE> \
  --description "New description..."
IMPORTANT: Title changes require a new app version submission. Keyword field + subtitle can be updated without a new binary.
2.3 — Track All Changes in Astro
After pushing to ASC, add ALL new keywords to Astro tracking:
Use Astro MCP:
For each locale and each new keyword pushed to ASC:
- Add to tracking (so we can monitor rank changes)
2.4 — Save Change Log
// ./aso-data/changelog/metadata_changes_{date}.json
{
  "date": "2026-03-25",
  "changes": [
    {
      "locale": "us",
      "field": "keywords",
      "before": "old,keywords,here",
      "after": "new,optimized,keywords",
      "new_keywords_added_to_astro": ["optimized", "keywords"]
    }
  ]
}
Phase 3: Measure — Daily Monitoring Loop
3.1 — Daily Report Script
Run every morning. Collects data from ALL three sources:
DAILY REPORT — {date}

## ASO Performance (Astro MCP)
Use Astro MCP:
1. get_app_keywords — current rankings for ALL tracked keywords
2. get_historical_rankings — compare today vs 7 days ago
3. search_rankings — check if any new keywords entered top 50

Output:
- Keywords improved: [list with old → new rank]
- Keywords declined: [list with old → new rank]
- New rankings entered: [list]
- Lost rankings: [list]
- Average rank change: +/- N

## User Analytics (Mixpanel MCP)
Query Mixpanel for:
1. DAU (Daily Active Users) — today vs 7-day avg
2. New installs (organic) — today vs 7-day avg
3. Onboarding completion rate
4. Key conversion events (trial_started, subscription_started)
5. Retention D1, D7, D30

Output:
- DAU: X (trend: ↑/↓ Y%)
- Organic installs: X (trend: ↑/↓ Y%)
- Trial start rate: X%
- Conversion rate: X%

## Revenue (RevenueCat MPC)
Query RevenueCat for:
1. Current MRR
2. MRR change (today vs 7 days ago vs 30 days ago)
3. Active subscribers count
4. Trial → paid conversion rate
5. Churn rate
6. Revenue by country/locale

Output:
- MRR: $X (target: $Xk)
- MRR growth: +$X this week
- Active subs: X
- Trial conversion: X%
- Churn: X%
- Top revenue locales: [ranked list]

Save to: ./aso-data/reports/daily_report_{date}.md

3.2 — Weekly Comparison Report
Every 7 days, generate comparison:
WEEKLY COMPARISON — Week of {date}

## Keyword Rankings Delta
Compare get_historical_rankings: this week vs last week
- Total keywords tracked: X
- Improved: X keywords (avg +Y positions)
- Declined: X keywords (avg -Y positions)
- Entered top 10: [list]
- Dropped out of top 50: [list]

## Install ↔ Keyword Correlation
Cross-reference:
- Which keywords improved? → Did installs from those locales increase?
- Which locales saw install growth? → What keywords changed there?

## Revenue Impact
- MRR this week: $X
- MRR last week: $Y
- Delta: +/- $Z
- Organic install → trial → paid funnel this week vs last

## Action Items for Next Week
Based on data, recommend:
1. Keywords to double down on (improving + high potential)
2. Keywords to replace (not moving after 2+ weeks)
3. Locales to re-optimize (declining installs)
4. Metadata changes to test
Save to: ./aso-data/reports/weekly_comparison_{date}.md
Phase 4: Optimize — Data-Driven Iteration
4.1 — Keyword Performance Scoring

After 7+ days of data, score each keyword:

SCORE = (popularity × 0.4) + ((100 - difficulty) × 0.3) + (rank_improvement × 0.3)

Categories:
- WINNER (score > 70, rank improving) → Keep, protect
- POTENTIAL (score > 50, rank stagnant) → Optimize placement (move to title/subtitle?)
- UNDERPERFORMER (score < 30, no rank after 14 days) → Replace
- NEW_OPPORTUNITY (not tracked, competitor ranks well) → Add

4.2 — Metadata Rotation Strategy

Every 2 weeks:
1. Run Phase 1 research again (markets shift)
2. Score all keywords with 4.1 formula
3. KEEP winners in keyword field
4. REPLACE underperformers with new opportunities
5. A/B test subtitle variations (rotate every version update)
6. Push changes via Phase 2
7. Log everything in changelog

4.3 — Locale Prioritization
Based on RevenueCat revenue-by-country data:
TIER 1 (>10% of revenue): Full optimization every cycle
TIER 2 (2-10% of revenue): Optimize every other cycle
TIER 3 (<2% of revenue): Quarterly optimization

Re-tier monthly based on fresh revenue data.
Phase 5: Repeat Until Target MRR
Exit Condition
IF current_mrr >= target_mrr AND mrr_source == "100% organic":
    EXIT LOOP
    Generate final report
ELSE:
    GOTO Phase 1
Loop Cadence
DAILY:
  - Run Phase 3.1 (daily report)
  - Review keyword rank changes
  - Flag anomalies (sudden drops = competitor changes or algorithm update)

WEEKLY:
  - Run Phase 3.2 (weekly comparison)
  - Run Phase 4.1 (score keywords)
  - Decide: rotate keywords or hold?

BI-WEEKLY:
  - Run Phase 4.2 (metadata rotation)
  - Run Phase 1 again (fresh research)
  - Push new metadata via Phase 2

MONTHLY:
  - Run Phase 4.3 (re-tier locales)
  - Full competitor re-analysis
  - Strategic review: is organic-only working, or do we need to supplement?
File Structure Summary
./aso-data/
├── baseline/
│   └── current_keywords_{date}.json
├── research/
│   ├── {locale}_keyword_opportunities_{date}.json
│   ├── {locale}_competitor_analysis_{date}.json
│   └── {locale}_recommended_keywords_{date}.json
├── reports/
│   ├── daily_report_{date}.md
│   └── weekly_comparison_{date}.md
├── changelog/
│   └── metadata_changes_{date}.json
├── scores/
│   └── keyword_scores_{date}.json
└── config/
    ├── locales.json          # active locale list
    ├── targets.json          # MRR target, tier thresholds
    └── competitors.json      # tracked competitor app IDs

Quick Reference: MCP Tool Mapping

Task MCP Server Tool     List tracked apps Astro list_apps   Get app keywords + ranks Astro get_app_keywords   Search keyword rankings Astro search_rankings   Historical rank data Astro get_historical_rankings   Daily active users Mixpanel query_events   Conversion funnel Mixpanel query_funnel   Retention cohorts Mixpanel query_retention   Current MRR RevenueCat get_overview   Subscriber details RevenueCat get_subscribers   Revenue by country RevenueCat get_revenue   Push keywords to ASC ASC CLI asc apps info update   Backup metadata ASC CLI asc apps info get

Notes

Do NOT skip saving outputs. Every data point is needed for comparison.
Always backup before pushing. ASC metadata changes are immediate.
Astro reads from local SQLite. Keep the Astro macOS app running and synced.
Rate limits: Astro MCP reads local DB (no limits). Mixpanel/RevenueCat APIs have rate limits — batch queries.
Keyword field has NO spaces after commas. "word1,word2,word3" not "word1, word2, word3".
Apple deduplicates across title + subtitle + keyword field. Never repeat a word.
