[![CI](https://github.com/AndriyKalashnykov/go-csv-struct/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/go-csv-struct/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/go-csv-struct.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/go-csv-struct/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/go-csv-struct)

# go-csv-struct

A Go library that converts CSV records into Go structs using reflection and `csv` struct tags. It supports nested structs and the types: `string`, `int`, `bool`, `float32`, `float64`. Fields without a `csv` tag are skipped.

## Quick Start

```bash
make deps      # install tool dependencies
make build     # compile the project
make test      # run tests with coverage
make run       # run the example application
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Go](https://go.dev/dl/) | 1.24+ | Go runtime and compiler |
| [GNU Make](https://www.gnu.org/software/make/) | 3.81+ | Build orchestration |
| [Git](https://git-scm.com/) | 2.0+ | Version control |

Install all required tool dependencies:

```bash
make deps
```

## Usage

See the complete runnable example in [`example/`](example/).

```go
package main

import (
	"encoding/csv"
	"fmt"
	"io"
	"os"

	csvtostruct "github.com/AndriyKalashnykov/csvtostruct"
)

type Record struct {
	Name  string  `csv:"name"`
	Age   int     `csv:"age"`
	Score float64 `csv:"score"`
}

func main() {
	file, err := os.Open("test.csv")
	if err != nil {
		fmt.Println("error opening file:", err)
		return
	}
	defer file.Close()

	reader := csv.NewReader(file)

	// Read the header row
	headers, err := reader.Read()
	if err != nil {
		fmt.Println("error reading headers:", err)
		return
	}

	// Create a parser and validate headers
	parser, err := csvtostruct.NewCSVStructer(&Record{}, headers)
	if err != nil {
		fmt.Println("error creating parser:", err)
		return
	}
	if !parser.ValidateHeaders(headers) {
		fmt.Println("CSV headers do not match struct tags")
		return
	}

	// Read and parse each data row
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			fmt.Println("error reading record:", err)
			continue
		}

		var r Record
		if err := parser.ScanStruct(record, &r); err != nil {
			fmt.Println("parse error:", err)
			continue
		}
		fmt.Printf("%+v\n", r)
	}
}
```

## Available Make Targets

Run `make help` to see all available targets.

### Build & Run

| Target | Description |
|--------|-------------|
| `make build` | Build and verify compilation |
| `make run` | Run example application |
| `make fmt` | Format Go files (gofumpt + gci) |
| `make clean` | Clean up environment |

### Code Quality

| Target | Description |
|--------|-------------|
| `make lint` | Alias for static-check |
| `make static-check` | Run all static analysis checks |
| `make fmtcheck` | Check formatting without modifying files |
| `make staticcheck` | Run staticcheck |
| `make spellcheck` | Spell check |
| `make critic` | Run gocritic |
| `make sec` | Run gosec security scanner |
| `make vulncheck` | Run Go vulnerability check on dependencies |
| `make secrets` | Scan for hardcoded secrets in source code and git history |

### Testing

| Target | Description |
|--------|-------------|
| `make test` | Run tests with coverage |
| `make coverage` | Run tests with HTML coverage report |
| `make coverage-check` | Verify coverage meets 80% threshold |
| `make fuzz` | Run fuzz tests for 30 seconds |

### CI

| Target | Description |
|--------|-------------|
| `make ci` | Run full CI pipeline locally |
| `make ci-full` | Run full CI pipeline including coverage |
| `make ci-run` | Run GitHub Actions workflow locally via [act](https://github.com/nektos/act) |
| `make check` | Run pre-commit checklist |

### Utilities

| Target | Description |
|--------|-------------|
| `make deps` | Install all tool dependencies (pinned versions) |
| `make update` | Update dependency packages to latest versions |
| `make release` | Create and push a new tag |
| `make renovate-validate` | Validate Renovate configuration |

## CI/CD

GitHub Actions runs on every push to `main`, tags `v*`, and pull requests.

| Job | Triggers | Steps |
|-----|----------|-------|
| **build** | push, PR, tags | Checkout, Setup Go, Build |
| **lint** | after build | Checkout, Setup Go, Cache tools, Static check |
| **test** | after build | Checkout, Setup Go, Cache tools, Coverage check (80%), Upload artifact |

A separate [cleanup workflow](.github/workflows/cleanup-runs.yml) deletes old workflow runs weekly (retains 7 days, minimum 5 runs).

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date with platform automerge enabled.
