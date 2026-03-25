# /verify — Pre-PR Verification Loop

Run all six verification phases before opening a pull request.

## Usage

```
/verify
```

## What This Does

Runs sequentially:

1. **Build** — `xcodebuild` Debug build
2. **Lint** — SwiftLint with `.swiftlint.yml`
3. **Tests** — Full XCTest suite with coverage
4. **Security** — Secrets and print() scan
5. **Diff** — Review changed files for unintended modifications
6. **Report** — READY / NOT READY summary

## Activates Skill

`verification-loop` + `security-review`

## Stop Conditions

- Stops at Phase 1 if build fails
- Blocks PR if any hardcoded secret found in Phase 4

## Output

```
╔══════════════════════════════╗
║   ONE Verification Report    ║
╠══════════════════════════════╣
║ Build      ✅                ║
║ SwiftLint  ✅                ║
║ Tests      ✅  (47/47)       ║
║ Security   ✅                ║
║ Diff       ✅                ║
╠══════════════════════════════╣
║ Status     READY             ║
╚══════════════════════════════╝
```
