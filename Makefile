projectname?=go-csv-struct

# Tool versions
GOCRITIC_VERSION     := v0.14.3
GOSEC_VERSION        := v2.22.4
MISSPELL_VERSION     := v0.3.4
STATICCHECK_VERSION  := v0.7.0
GOFUMPT_VERSION      := v0.9.2
GCI_VERSION          := v0.14.0
GOIMPORTS_VERSION    := v0.43.0
GOVULNCHECK_VERSION  := v1.1.4
GITLEAKS_VERSION     := v8.24.0

PKGS         = $(shell go list ./... | grep -v /example)
GOFMT_FILES  = $(shell go list -f '{{.Dir}}' ./...)
CURRENTTAG:=$(shell git describe --tags --abbrev=0 2>/dev/null || echo "none")
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (current tag - ${CURRENTTAG}): " newtag; echo $$newtag')
GOFLAGS ?= -mod=mod

HOMEDIR := $(CURDIR)
OUTDIR  := $(HOMEDIR)/output
COVPROF := $(HOMEDIR)/coverage.out

.DEFAULT_GOAL := help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: deps
deps: ## download and install dependencies
	@command -v gocritic > /dev/null 2>&1 || { echo "Installing gocritic..."; go install github.com/go-critic/go-critic/cmd/gocritic@$(GOCRITIC_VERSION); }
	@command -v gosec > /dev/null 2>&1 || { echo "Installing gosec..."; go install github.com/securego/gosec/v2/cmd/gosec@$(GOSEC_VERSION); }
	@command -v misspell > /dev/null 2>&1 || { echo "Installing misspell..."; go install github.com/client9/misspell/cmd/misspell@$(MISSPELL_VERSION); }
	@command -v staticcheck > /dev/null 2>&1 || { echo "Installing staticcheck..."; go install honnef.co/go/tools/cmd/staticcheck@$(STATICCHECK_VERSION); }
	@command -v gofumpt > /dev/null 2>&1 || { echo "Installing gofumpt..."; go install mvdan.cc/gofumpt@$(GOFUMPT_VERSION); }
	@command -v gci > /dev/null 2>&1 || { echo "Installing gci..."; go install github.com/daixiang0/gci@$(GCI_VERSION); }
	@command -v goimports > /dev/null 2>&1 || { echo "Installing goimports..."; go install golang.org/x/tools/cmd/goimports@$(GOIMPORTS_VERSION); }
	@command -v govulncheck > /dev/null 2>&1 || { echo "Installing govulncheck..."; go install golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION); }
	@command -v gitleaks > /dev/null 2>&1 || { echo "Installing gitleaks..."; go install github.com/zricethezav/gitleaks/v8@$(GITLEAKS_VERSION); }

.PHONY: fmt
fmt: deps ## format go files
	@gofumpt -w .
	@gci write .

.PHONY: fmtcheck
fmtcheck: deps ## format check
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
spellcheck: deps ## spell check
	@find . -type f \( -name '*.go' -o -name '*.md' -o -name '*.yml' -o -name '*.yaml' -o -name '*.txt' -o -name '*.csv' \) -not -path './.git/*' -not -path './vendor/*' -print0 | xargs -0 misspell -locale="US" -error -source="text"

.PHONY: staticcheck
staticcheck: deps ## static check
	@staticcheck -checks="all" -tests $(GOFMT_FILES)

.PHONY: critic
critic: deps ## run gocritic
	@gocritic check -enableAll ./...

.PHONY: sec
sec: deps ## run gosec security scanner
	@gosec ./...

.PHONY: vulncheck
vulncheck: deps ## run Go vulnerability check on dependencies
	@govulncheck ./...

.PHONY: secrets
secrets: deps ## scan for hardcoded secrets in source code and git history
	@gitleaks detect --source . --verbose --redact

.PHONY: static-check
static-check: deps fmtcheck staticcheck spellcheck sec critic vulncheck secrets ## run all static analysis checks
	@echo "Static check done."

.PHONY: lint
lint: static-check ## alias for static-check

.PHONY: build
build: fmt ## build and verify compilation
	@go build ./...

.PHONY: run
run: build ## run example application
	@go run ./example/...

.PHONY: test
test: clean ## run tests with coverage
	@go test --cover -parallel=1 -v -coverprofile=$(COVPROF) $(PKGS)
	@go tool cover -func=$(COVPROF) | sort -rnk3

.PHONY: coverage
coverage: clean ## run tests with HTML coverage report
	@mkdir -p $(OUTDIR)
	@go test --cover -parallel=1 -v -coverprofile=$(COVPROF) -covermode=atomic $(PKGS)
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

NVM_VERSION := 0.40.4

.PHONY: renovate-bootstrap
renovate-bootstrap: ## install nvm and npm for Renovate
	@command -v node >/dev/null 2>&1 || { \
		echo "Installing nvm $(NVM_VERSION)..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install --lts; \
	}

.PHONY: renovate-validate
renovate-validate: renovate-bootstrap ## validate Renovate configuration
	@npx --yes renovate --platform=local
