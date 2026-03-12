# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`csvtostruct` is a Go library that converts CSV records into Go structs using reflection and `csv` struct tags. It supports nested structs and the types: string, int, bool, float32, float64. Fields without a `csv` tag are skipped.

Module path: `github.com/AndriyKalashnykov/csvtostruct`

## Build & Development Commands

```bash
make deps          # Install all tool dependencies (golangci-lint, gofumpt, gci, goimports, gocritic, gosec, etc.)
make fmt           # Format code (gofumpt + gci)
make fmtcheck      # Check formatting without modifying files
make staticcheck   # Run staticcheck
make spellcheck    # Run misspell
make critic        # Run gocritic check -enableAll
make sec           # Run gosec
make build         # Full build: fmt, fmtcheck, staticcheck, spellcheck, sec, critic, then go build
make test          # Run tests with coverage (cleans first)
make clean         # Remove coverage.out, dist/, completions/, manpages/, binary
make update        # Update all dependencies to latest
```

Run a single test:
```bash
go test -run TestParser -v ./...
```

## Architecture

This is a single-package library (`package csv`) with two files:

- **CSVParser.go** — All library code. `CSVStruct` holds expected headers. `NewCSVStructer()` creates an instance, `ValidateHeaders()` checks CSV headers match, `ScanStruct()` maps a CSV row to a struct pointer using reflection on `csv` struct tags. Nested exported structs are scanned recursively.
- **CSVParser_test.go** — Tests using `testify/assert`. Covers all supported types, nested structs, unexported field errors, parse errors, non-pointer input, header validation.

`tools/tools.go` is a build-tagged (`//go:build tools`) file that pins dev tool dependencies via blank imports.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on push/PR: lint (`fmtcheck`, `staticcheck`, `spellcheck`, `sec`, `critic`) then `build` and `test`.

## Testing Notes

- Tests use `testify/assert` (not the stdlib `testing` alone)
- `test.csv` is a fixture file used by `TestParser_FromCSVFile`
- The `stretchr/testify` package is the only runtime test dependency
