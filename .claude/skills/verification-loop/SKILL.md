# Verification Loop

Six-phase quality check for ONE before opening a PR. Runs build, lint, tests, security scan, and diff review in sequence.

## When to Activate

- Before opening any PR
- After completing a significant feature or refactor
- When a `/verify` command is run

## The Six Phases

### Phase 1: Build

```bash
xcodebuild \
  -project ones.xcodeproj \
  -scheme ones \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build | xcpretty
```

**Stop if:** Build fails — all other phases are meaningless.

### Phase 2: SwiftLint

```bash
swiftlint lint --config .swiftlint.yml --reporter emoji
```

**Fix:** All errors; warnings optional but noted.

### Phase 3: Tests

```bash
xcodebuild test \
  -project ones.xcodeproj \
  -scheme ones \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES \
  | xcpretty --test
```

**Target:** All tests pass; coverage ≥ 80% on modified files.

### Phase 4: Security Scan

```bash
# Hardcoded secrets
grep -rn "f2afa405\|clientSecret\|password\s*=\s*\"" one/ --include="*.swift"

# print() instead of ONELogger
grep -rn "^\s*print(" one/ --include="*.swift"

# Force unwrap
grep -rn "[^!]=![^=]" one/ --include="*.swift"

# Info.plist string literals (should use xcconfig vars)
grep -B1 -A1 "ClientID\|APIKey" one/Info.plist
```

**Block PR if:** Any hardcoded secret or API key found.

### Phase 5: Diff Review

```bash
git diff main...HEAD --stat
git diff main...HEAD -- "*.swift" | head -200
```

Check for:
- [ ] No unintended file changes
- [ ] No commented-out code blocks left in
- [ ] All `TODO` / `FIXME` either resolved or filed as issues
- [ ] No `print()` debug statements

### Phase 6: Report

```
╔══════════════════════════════╗
║   ONE Verification Report    ║
╠══════════════════════════════╣
║ Build      ✅ / ❌           ║
║ SwiftLint  ✅ / ❌           ║
║ Tests      ✅ / ❌  (N/M)    ║
║ Security   ✅ / ❌           ║
║ Diff       ✅ / ❌           ║
╠══════════════════════════════╣
║ Status     READY / NOT READY ║
╚══════════════════════════════╝
```

## Quick Run (all phases)

```bash
set -e
echo "Phase 1: Build..."
xcodebuild -project ones.xcodeproj -scheme ones -configuration Debug build > /dev/null && echo "✅ Build passed"

echo "Phase 2: Lint..."
swiftlint lint --quiet && echo "✅ Lint passed"

echo "Phase 3: Tests..."
xcodebuild test -project ones.xcodeproj -scheme ones \
  -destination 'platform=iOS Simulator,name=iPhone 15' -quiet && echo "✅ Tests passed"

echo "Phase 4: Security..."
! grep -rn "f2afa405\|^\s*print(" one/ --include="*.swift" -l && echo "✅ Security passed"

echo "Phase 5: Diff..."
git diff main...HEAD --stat
echo "✅ All phases complete — READY"
```

## References

- See skill: `security-review` for detailed secrets audit
- See skill: `tdd-workflow` for writing missing tests
