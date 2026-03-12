# go-csv-struct

[![ci](https://github.com/AndriyKalashnykov/go-csv-struct/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/go-csv-struct/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/go-csv-struct.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/go-csv-struct/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/go-csv-struct)

Go Package to convert CSV fields to Struct

# About

csvtostruct is a minimalistic package to help you convert your CSV records to struct objects. csvtostruct also supports the
use of nested structs.

# Usage

```
type testParser1 struct {
	Field1 string `csv:"field1"`
	Field2 int    `csv:"field2"`
}
headerFields := []string{"field1" , "field2"}
row := 0
for {
	record, err := testFile.Read()
	if err == io.EOF {
		break
	}

    newCSVParser := csv.NewCSVStructer(&testParser1{}, headerFields)
    if row == 0 {
      if !csv.ValidateHeaders(record) {
	break
      }
      row+=1
    }
    var parser testParser1
    err := csv.ScanStruct(record , &parser)
    // Now parser struct will contain the csv record
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
