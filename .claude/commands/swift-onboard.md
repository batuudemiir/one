# /swift-onboard — Codebase Onboarding

Analyse the ONE codebase and regenerate `CLAUDE.md` with up-to-date project context.

## Usage

```
/swift-onboard
```

## What This Does

1. Scans `Core/`, `Features/`, `UI/` directory structure
2. Detects new managers, models, and feature modules added since last run
3. Updates `CLAUDE.md` with current file counts, key entry points, and conventions
4. Lists any new managers missing protocol abstractions
5. Flags any new Swift files not covered by tests

## Activates Skill

`codebase-onboarding` + `swift-protocol-di-testing`

## Output

Updates `CLAUDE.md` in place and prints a diff summary:

```
=== CLAUDE.md Updated ===
+ Added: EchoFeatureViewModel (Features/Echo/)
+ Added: CloudKitEchoService (Core/Managers/)
~ Updated file counts: 96 → 102 Swift files
! Missing tests: EchoViewModelTests, CloudKitEchoServiceTests
! Missing protocol: CloudKitEchoService has no abstract protocol
```
