# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`csvtostruct` is a Go library that converts CSV records into Go structs using reflection and `csv` struct tags. It supports nested structs and the types: string, int, bool, float32, float64. Fields without a `csv` tag are skipped.

Module path: `github.com/AndriyKalashnykov/csvtostruct`

## Build & Development Commands

```bash
make deps             # Install all tool dependencies (pinned versions)
make deps-check       # Show required Go versions and gvm status
make deps-act         # Install act for local CI
make deps-prune       # Remove unused Go dependencies
make deps-prune-check # Verify no prunable dependencies (CI gate)
make fmt              # Format code (gofumpt + gci)
make format           # Alias for fmt
make fmtcheck         # Check formatting without modifying files
make staticcheck      # Run staticcheck
make spellcheck       # Run misspell
make critic           # Run gocritic check -enableAll
make sec              # Run gosec
make vulncheck        # Run govulncheck on dependencies
make secrets          # Scan for hardcoded secrets (gitleaks)
make static-check     # Run all static analysis checks
make lint             # Alias for static-check
make build            # Compile (go build)
make run              # Run example application
make test             # Run tests with coverage
make coverage         # Run tests with HTML coverage report
make coverage-check   # Verify coverage meets 80% threshold
make fuzz             # Run fuzz tests for 30 seconds
make ci               # Run full CI pipeline locally
make ci-full          # Run full CI pipeline including coverage
make ci-run           # Run GitHub Actions workflow locally via act
make check            # Run pre-commit checklist
make clean            # Remove build artifacts and test cache
make update           # Update all dependencies to latest
make release          # Create and push a new tag
make renovate-bootstrap   # Install nvm and npm for Renovate
make renovate-validate    # Validate Renovate configuration
```

Run a single test:
```bash
go test -run TestParser -v ./...
```

## Architecture

This is a single-package library (`package csv`) with two files:

- **CSVParser.go** — All library code. `CSVStruct` holds expected headers. `NewCSVStructer()` creates an instance, `ValidateHeaders()` checks CSV headers match, `ScanStruct()` maps a CSV row to a struct pointer using reflection on `csv` struct tags. Nested exported structs are scanned recursively.
- **CSVParser_test.go** — Tests using `testify/assert`. Covers all supported types, nested structs, unexported field errors, parse errors, non-pointer input, header validation. Also contains fuzz tests for input validation (`make fuzz`).

`tools/tools.go` is a build-tagged (`//go:build tools`) file that pins dev tool dependencies via blank imports.

## CI

GitHub Actions (`.github/workflows/ci.yml`) triggers on pushes to `main`, tags `v*`, and pull requests, with concurrency control that cancels in-progress runs on the same ref. The `build` job runs first (`make build`); `lint` and `test` run in parallel after build passes (`needs: build`). `lint` runs `make static-check` (fmtcheck, staticcheck, spellcheck, sec, critic, vulncheck, secrets) and sets `fetch-depth: 0` for gitleaks git history scanning. `test` runs `make coverage-check` with an 80% threshold and uploads `coverage.out` as an artifact (retained for 14 days). All jobs have a 10-minute timeout and cache Go tool binaries across runs.

A separate cleanup workflow (`.github/workflows/cleanup-runs.yml`) deletes old workflow runs weekly.

## Testing Notes

- Tests use `testify/assert` (not the stdlib `testing` alone)
- `test.csv` is a fixture file used by `TestParser_FromCSVFile`
- The `stretchr/testify` package is the only runtime test dependency

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.yml` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
