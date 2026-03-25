# Security Review

Security audit checklist for iOS/Swift apps. Covers secrets management, API key hygiene, authentication, and data protection. Critical for ONE given Spotify + CloudKit + Ticketmaster integrations.

## When to Activate

- Before any PR that touches `Info.plist`, `Secrets.xcconfig`, entitlements, or manager files
- When adding a new API integration
- After any git rebase or merge that touches config files
- Running `/security-scan` command

## ⚠️ Known Issue in ONE

`Info.plist` currently contains the Spotify Client ID in plain text.
This must be moved to `Secrets.xcconfig` before the next App Store submission.

```xml
<!-- REMOVE from Info.plist -->
<key>SpotifyClientID</key>
<string>f2afa405bc0e44bf8ed6c171adc0fa79</string>

<!-- ADD to Secrets.xcconfig -->
SPOTIFY_CLIENT_ID = f2afa405bc0e44bf8ed6c171adc0fa79

<!-- REFERENCE in Info.plist -->
<key>SpotifyClientID</key>
<string>$(SPOTIFY_CLIENT_ID)</string>
```

## Checklist

### 1. Secrets Management

- [ ] No API keys hardcoded in `.swift` files
- [ ] No API keys in `Info.plist` as string literals — use `$(XCCONFIG_VAR)`
- [ ] `Secrets.xcconfig` is in `.gitignore`
- [ ] `Secrets.xcconfig` is NOT committed to git history
- [ ] All new keys added to `Secrets.xcconfig.template` (with placeholder values)
- [ ] Ticketmaster API key uses xcconfig variable

```bash
# Scan for hardcoded secrets
grep -rn "clientId\|apiKey\|secret\|password\|token" one/ \
  --include="*.swift" --include="*.plist" \
  | grep -v "xcconfig\|template\|test\|mock"
```

### 2. CloudKit & User Data

- [ ] `CloudKitManager` does not log user data via `print()` — use `ONELogger`
- [ ] `DailyEntry` fields that are private (mood, photos) are not exposed publicly
- [ ] Friend requests validated before accepting
- [ ] CloudKit record IDs not exposed in UI error messages

### 3. Spotify Auth

- [ ] Access token stored in Keychain, NOT `UserDefaults`
- [ ] Token refresh handled — no expired token crashes
- [ ] Redirect URI matches `ones://spotify-callback` exactly
- [ ] Spotify Client ID loaded from xcconfig at build time

### 4. Deep Links

- [ ] `ones://add-friend` validates the payload before processing
- [ ] `ones://spotify-callback` only handles expected query parameters
- [ ] No arbitrary URL scheme handling without validation

### 5. Data Exposure

- [ ] `ONELogger` never logs mood data, song history, or friend lists in production
- [ ] Error messages shown to users don't include CloudKit record IDs
- [ ] No sensitive data in crash reports / analytics

### 6. Transport Security

- [ ] App Transport Security (ATS) not disabled in `Info.plist`
- [ ] All network requests use HTTPS

### 7. Git History

```bash
# Check git history for accidentally committed secrets
git log --all --full-history -- "Secrets.xcconfig"
git grep "clientId\|apiKey" $(git rev-list --all)
```

## Quick Scan Command

```bash
# Run from project root
echo "=== Checking for hardcoded secrets ===" && \
grep -rn "f2afa405\|clientSecret\|apiKey\s*=\s*\"" one/ --include="*.swift" && \
echo "=== Checking Info.plist for string literals ===" && \
grep -A1 "ClientID\|APIKey\|Secret" one/Info.plist && \
echo "=== Checking .gitignore covers Secrets ===" && \
grep "Secrets.xcconfig" .gitignore
```

## References

- `Secrets.xcconfig.template` — template for all required keys
- `one.entitlements` — CloudKit container configuration
- `SpotifyManager.swift` — Spotify auth implementation
