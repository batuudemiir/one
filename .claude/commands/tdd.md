# /tdd — Test-Driven Development

Start a TDD cycle for a new feature or bug fix in the ONE app.

## Usage

```
/tdd <feature-or-bug-description>
```

## What This Does

1. Ask for a user story if not provided
2. Generate test cases (happy path, error, edge cases)
3. Write failing tests in the appropriate `oneTests/` file
4. Implement minimum code to make tests pass
5. Refactor and verify coverage

## Activates Skill

`tdd-workflow` + `swift-protocol-di-testing`

## Example

```
/tdd Save today's mood entry to CloudKit
```

Claude will:
- Write `TodayViewModelTests` with `MockDailyEntryStore`
- Implement `saveEntry()` on `TodayViewModel`
- Run tests and confirm green
- Check coverage on modified files
