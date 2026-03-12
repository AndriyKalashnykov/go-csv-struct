projectname?=go-csv-struct

GOFMT_FILES = $(shell go list -f '{{.Dir}}' ./...)
CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (current tag - ${CURRENTTAG}): " newtag; echo $$newtag')
GOFLAGS ?= -mod=mod

HOMEDIR := $(CURDIR)
OUTDIR  := $(HOMEDIR)/output
COVPROF := $(HOMEDIR)/coverage.out

default: help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: deps
deps: ## download and install dependencies
	@command -v gocritic > /dev/null 2>&1 || { echo "Installing gocritic..."; go install github.com/go-critic/go-critic/cmd/gocritic@v0.14.3; }
	@command -v gosec > /dev/null 2>&1 || { echo "Installing gosec..."; go install github.com/securego/gosec/v2/cmd/gosec@v2.22.4; }
	@command -v misspell > /dev/null 2>&1 || { echo "Installing misspell..."; go install github.com/client9/misspell/cmd/misspell@v0.3.4; }
	@command -v staticcheck > /dev/null 2>&1 || { echo "Installing staticcheck..."; go install honnef.co/go/tools/cmd/staticcheck@v0.7.0; }
	@command -v gofumpt > /dev/null 2>&1 || { echo "Installing gofumpt..."; go install mvdan.cc/gofumpt@v0.9.2; }
	@command -v gci > /dev/null 2>&1 || { echo "Installing gci..."; go install github.com/daixiang0/gci@v0.14.0; }
	@command -v goimports > /dev/null 2>&1 || { echo "Installing goimports..."; go install golang.org/x/tools/cmd/goimports@v0.43.0; }
	@command -v govulncheck > /dev/null 2>&1 || { echo "Installing govulncheck..."; go install golang.org/x/vuln/cmd/govulncheck@latest; }
	@command -v gitleaks > /dev/null 2>&1 || { echo "Installing gitleaks..."; go install github.com/zricethezav/gitleaks/v8@v8.24.0; }

.PHONY: fmt
fmt: ## format go files
	@gofumpt -w .
	@gci write .

.PHONY: fmtcheck
fmtcheck: ## format check
	@CHANGES="$$(goimports -d $(GOFMT_FILES))"; \
		if [ -n "$${CHANGES}" ]; then \
			echo "Unformatted (run goimports -w .):\n\n$${CHANGES}\n\n"; \
			exit 1; \
		fi
	@# Annoyingly, goimports does not support the simplify flag.
	@CHANGES="$$(gofmt -s -d $(GOFMT_FILES))"; \
		if [ -n "$${CHANGES}" ]; then \
			echo "Unformatted (run gofmt -s -w .):\n\n$${CHANGES}\n\n"; \
			exit 1; \
		fi

.PHONY: spellcheck
spellcheck: ## spell check
	@find . -type f \( -name '*.go' -o -name '*.md' -o -name '*.yml' -o -name '*.yaml' -o -name '*.txt' -o -name '*.csv' \) -not -path './.git/*' -not -path './vendor/*' -print0 | xargs -0 misspell -locale="US" -error -source="text"

.PHONY: staticcheck
staticcheck: ## static check
	@staticcheck -checks="all" -tests $(GOFMT_FILES)

.PHONY: critic
critic: ## run gocritic
	gocritic check -enableAll ./...

.PHONY: sec
sec: ## run gosec security scanner
	gosec ./...

.PHONY: vulncheck
vulncheck: deps ## run Go vulnerability check on dependencies
	govulncheck ./...

.PHONY: secrets
secrets: deps ## scan for hardcoded secrets in source code and git history
	gitleaks detect --source . --verbose --redact

.PHONY: static-check
static-check: deps fmtcheck staticcheck spellcheck sec critic vulncheck secrets ## run all static analysis checks
	@echo "Static check done."

.PHONY: build
build: fmt ## build and verify compilation
	@go build ./...

.PHONY: test
test: clean ## run tests with coverage
	go test --cover -parallel=1 -v -coverprofile=$(COVPROF) ./...
	go tool cover -func=$(COVPROF) | sort -rnk3

.PHONY: coverage
coverage: clean ## run tests with HTML coverage report
	@mkdir -p $(OUTDIR)
	go test --cover -parallel=1 -v -coverprofile=$(COVPROF) -covermode=atomic ./...
	@go tool cover -func=$(COVPROF)
	@go tool cover -html=$(COVPROF) -o $(OUTDIR)/coverage.html
	@echo "Coverage report: $(OUTDIR)/coverage.html"

.PHONY: coverage-check
coverage-check: coverage ## verify coverage meets 80% threshold
	@TOTAL=$$(go tool cover -func=$(COVPROF) | grep total | awk '{print $$3}' | tr -d '%'); \
	echo "Coverage: $${TOTAL}%"; \
	if awk "BEGIN {exit !($${TOTAL} < 80)}"; then \
		echo "FAIL: Coverage $${TOTAL}% is below 80% threshold"; exit 1; \
	else \
		echo "PASS: Coverage meets 80% threshold"; \
	fi

.PHONY: fuzz
fuzz: ## run fuzz tests for 30 seconds
	@export GOFLAGS=$(GOFLAGS); go test ./... -fuzz=Fuzz -fuzztime=30s

.PHONY: clean
clean: ## clean up environment
	@rm -rf $(COVPROF) $(OUTDIR) dist/ completions/ manpages/ $(projectname)
	@go clean -testcache

.PHONY: update
update: ## update dependency packages to latest versions
	@go get -u ./...; go mod tidy

.PHONY: release
release: static-check test build ## create and push a new tag
	$(eval NT=$(NEWTAG))
	@echo "$(NT)" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "Error: Tag must match vN.N.N"; exit 1; }
	@echo -n "Are you sure to create and push ${NT} tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo ${NT} > ./version.txt
	@git add -A
	@git commit -a -s -m "Cut ${NT} release"
	@git tag ${NT}
	@git push origin ${NT}
	@git push
	@echo "Done."

.PHONY: ci
ci: static-check build test ## run full CI pipeline locally
	@echo "Local CI pipeline passed."

.PHONY: ci-full
ci-full: static-check build coverage-check ## run full CI pipeline including coverage
	@echo "Full CI pipeline passed."

.PHONY: check
check: static-check test build ## run pre-commit checklist
	@echo "All pre-commit checks passed."
