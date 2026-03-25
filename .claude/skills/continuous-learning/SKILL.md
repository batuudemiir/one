# Continuous Learning

Automatically extract reusable patterns from Claude Code sessions and save them as learned skills. Activated at session end.

## When to Activate

- At the end of any session where a non-obvious bug was fixed
- When a CloudKit / Spotify SDK quirk was discovered and worked around
- When a SwiftUI re-render or concurrency issue was debugged
- When user corrects Claude's approach — capture the correction

## Pattern Categories to Capture

| Category | Examples for ONE |
|----------|-----------------|
| `error_resolution` | CloudKit `CKError.networkFailure` retry logic |
| `user_corrections` | "Use `ONELogger` not `print()`" |
| `workarounds` | Spotify SDK token refresh edge case |
| `debugging_techniques` | Core Data context threading fix |
| `project_specific` | ONE mood enum ordering, DM Sans font names |

## Output Format

Patterns are saved to `.claude/skills/learned/` as markdown:

```markdown
# Learned: CloudKit Retry on Network Failure
Date: 2026-03-25
Category: error_resolution

## Pattern
When `CKError.networkUnavailable` is thrown, wait 2s and retry once
before surfacing the error to the user.

## Context
Discovered while fixing Archive not loading on first launch with poor
connectivity.

## Code
```swift
func fetchWithRetry() async throws -> [DailyEntry] {
    do {
        return try await cloudKit.fetchEntries()
    } catch let error as CKError where error.code == .networkUnavailable {
        try await Task.sleep(for: .seconds(2))
        return try await cloudKit.fetchEntries()
    }
}
```
```

## Session Evaluation Criteria

Extract a pattern when:
- The fix took more than 2 back-and-forths to discover
- A compiler error required a non-obvious solution
- A framework API behaved differently than documented
- The user explicitly corrected Claude's approach

Skip extraction when:
- Simple typo fix
- Single-line change with obvious intent
- External API downtime (not a code pattern)

## Storage Location

```
one/.claude/skills/learned/
├── cloudkit-retry-pattern.md
├── spotify-token-refresh-edge-case.md
├── swiftui-list-rerender-fix.md
└── coredata-context-threading.md
```

## Setup (Stop Hook)

Add to `.claude/settings.json` to run at session end:

```json
{
  "hooks": {
    "Stop": [
      {
        "description": "Evaluate session for extractable patterns",
        "command": "echo 'Session ended. Review conversation for patterns worth saving to .claude/skills/learned/'"
      }
    ]
  }
}
```
