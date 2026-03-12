Run the full pre-commit checklist for this project. Execute each step sequentially and report results:

1. `go vet ./...` — Go vet
2. `make fmt` — Format code (gofumpt + gci)
3. `make fmtcheck` — Verify formatting
4. `make staticcheck` — Static analysis
5. `make spellcheck` — Spell check
6. `make sec` — Security scan (gosec)
7. `make critic` — Go critic
8. `make test` — Unit tests with coverage
9. `make build` — Compile

After all steps, provide a summary table showing pass/fail status for each check. If any step fails, show the relevant error output and suggest a fix.
