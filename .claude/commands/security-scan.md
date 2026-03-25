# /security-scan — Security Audit

Run a security review of the ONE codebase, focusing on API keys, secrets, and data exposure.

## Usage

```
/security-scan
/security-scan <file-or-directory>
```

## What This Does

1. Scans for hardcoded API keys and secrets in Swift files and plists
2. Checks `Info.plist` for string literals that should use xcconfig variables
3. Verifies `Secrets.xcconfig` is gitignored
4. Scans for `print()` calls that should use `ONELogger`
5. Checks for force unwraps (`!`) in production code
6. Reports findings with file + line references

## Activates Skill

`security-review`

## Known Issues to Check

- Spotify Client ID in `Info.plist` (must move to `Secrets.xcconfig`)
- Ticketmaster API key configuration
- CloudKit user data logging

## Output

```
=== ONE Security Scan ===
[CRITICAL] Info.plist:42 — Spotify Client ID hardcoded
[WARNING]  SpotifyManager.swift:87 — print() used instead of ONELogger
[OK]       Secrets.xcconfig not in git history
```
