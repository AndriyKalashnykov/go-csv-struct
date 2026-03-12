# go-csv-struct

[![ci](https://github.com/AndriyKalashnykov/go-csv-struct/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/go-csv-struct/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/go-csv-struct.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/go-csv-struct/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/go-csv-struct)

Go Package to convert CSV fields to Struct

# About

`csvtostruct` converts CSV records into Go structs using `csv` struct tags. It supports nested structs and the following field types: `string`, `int`, `bool`, `float32`, `float64`. Fields without a `csv` tag are skipped.

# Usage

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

# Help

```text
Usage: make COMMAND
Commands :
  help            - List available tasks
  deps            - Download and install dependencies
  fmt             - Format go files
  fmtcheck        - Format check
  spellcheck      - Spell check
  staticcheck     - Static check
  critic          - Run gocritic
  sec             - Run gosec security scanner
  vulncheck       - Run Go vulnerability check on dependencies
  secrets         - Scan for hardcoded secrets in source code and git history
  static-check    - Run all static analysis checks
  build           - Build and verify compilation
  test            - Run tests with coverage
  coverage        - Run tests with HTML coverage report
  coverage-check  - Verify coverage meets 80% threshold
  fuzz            - Run fuzz tests for 30 seconds
  clean           - Clean up environment
  update          - Update dependency packages to latest versions
  release         - Create and push a new tag
  ci              - Run full CI pipeline locally
  ci-full         - Run full CI pipeline including coverage
  check           - Run pre-commit checklist
```
