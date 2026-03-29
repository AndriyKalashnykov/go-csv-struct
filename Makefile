.DEFAULT_GOAL := help

APP_NAME       := go-csv-struct
CURRENTTAG     := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

# === Tool Versions (pinned) ===
GOCRITIC_VERSION     := v0.14.3
GOSEC_VERSION        := v2.22.4
MISSPELL_VERSION     := v0.3.4
STATICCHECK_VERSION  := v0.7.0
GOFUMPT_VERSION      := v0.9.2
GCI_VERSION          := v0.14.0
GOIMPORTS_VERSION    := v0.43.0
GOVULNCHECK_VERSION  := v1.1.4
GITLEAKS_VERSION     := v8.24.0
ACT_VERSION          := 0.2.86
NVM_VERSION          := 0.40.4

PKGS         = $(shell go list ./... | grep -v /example)
GOFMT_FILES  = $(shell go list -f '{{.Dir}}' ./...)
GOFLAGS      ?= -mod=mod

HOMEDIR := $(CURDIR)
OUTDIR  := $(HOMEDIR)/output
COVPROF := $(HOMEDIR)/coverage.out

#help: @ List available tasks
help:
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-20s\033[0m - %s\n", $$1, $$2}'

#deps: @ Install all tool dependencies (pinned versions)
deps:
	@command -v gocritic > /dev/null 2>&1 || { echo "Installing gocritic..."; go install github.com/go-critic/go-critic/cmd/gocritic@$(GOCRITIC_VERSION); }
	@command -v gosec > /dev/null 2>&1 || { echo "Installing gosec..."; go install github.com/securego/gosec/v2/cmd/gosec@$(GOSEC_VERSION); }
	@command -v misspell > /dev/null 2>&1 || { echo "Installing misspell..."; go install github.com/client9/misspell/cmd/misspell@$(MISSPELL_VERSION); }
	@command -v staticcheck > /dev/null 2>&1 || { echo "Installing staticcheck..."; go install honnef.co/go/tools/cmd/staticcheck@$(STATICCHECK_VERSION); }
	@command -v gofumpt > /dev/null 2>&1 || { echo "Installing gofumpt..."; go install mvdan.cc/gofumpt@$(GOFUMPT_VERSION); }
	@command -v gci > /dev/null 2>&1 || { echo "Installing gci..."; go install github.com/daixiang0/gci@$(GCI_VERSION); }
	@command -v goimports > /dev/null 2>&1 || { echo "Installing goimports..."; go install golang.org/x/tools/cmd/goimports@$(GOIMPORTS_VERSION); }
	@command -v govulncheck > /dev/null 2>&1 || { echo "Installing govulncheck..."; go install golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION); }
	@command -v gitleaks > /dev/null 2>&1 || { echo "Installing gitleaks..."; go install github.com/zricethezav/gitleaks/v8@$(GITLEAKS_VERSION); }

#fmt: @ Format Go files (gofumpt + gci)
fmt: deps
	@gofumpt -w .
	@gci write .

#fmtcheck: @ Check formatting without modifying files
fmtcheck: deps
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

#spellcheck: @ Spell check
spellcheck: deps
	@find . -type f \( -name '*.go' -o -name '*.md' -o -name '*.yml' -o -name '*.yaml' -o -name '*.txt' -o -name '*.csv' \) -not -path './.git/*' -not -path './vendor/*' -print0 | xargs -0 misspell -locale="US" -error -source="text"

#staticcheck: @ Run staticcheck
staticcheck: deps
	@staticcheck -checks="all" -tests $(GOFMT_FILES)

#critic: @ Run gocritic
critic: deps
	@gocritic check -enableAll ./...

#sec: @ Run gosec security scanner
sec: deps
	@gosec ./...

#vulncheck: @ Run Go vulnerability check on dependencies
vulncheck: deps
	@govulncheck ./...

#secrets: @ Scan for hardcoded secrets in source code and git history
secrets: deps
	@gitleaks detect --source . --verbose --redact

#static-check: @ Run all static analysis checks
static-check: deps fmtcheck staticcheck spellcheck sec critic vulncheck secrets
	@echo "Static check done."

#lint: @ Alias for static-check
lint: static-check

#build: @ Build and verify compilation
build: deps
	@go build ./...

#run: @ Run example application
run: build
	@go run ./example/...

#test: @ Run tests with coverage
test: deps
	@go clean -testcache
	@go test --cover -parallel=1 -v -coverprofile=$(COVPROF) $(PKGS)
	@go tool cover -func=$(COVPROF) | sort -rnk3

#coverage: @ Run tests with HTML coverage report
coverage: deps
	@go clean -testcache
	@mkdir -p $(OUTDIR)
	@go test --cover -parallel=1 -v -coverprofile=$(COVPROF) -covermode=atomic $(PKGS)
	@go tool cover -func=$(COVPROF)
	@go tool cover -html=$(COVPROF) -o $(OUTDIR)/coverage.html
	@echo "Coverage report: $(OUTDIR)/coverage.html"

#coverage-check: @ Verify coverage meets 80% threshold
coverage-check: coverage
	@TOTAL=$$(go tool cover -func=$(COVPROF) | grep total | awk '{print $$3}' | tr -d '%'); \
	echo "Coverage: $${TOTAL}%"; \
	if awk "BEGIN {exit !($${TOTAL} < 80)}"; then \
		echo "FAIL: Coverage $${TOTAL}% is below 80% threshold"; exit 1; \
	else \
		echo "PASS: Coverage meets 80% threshold"; \
	fi

#fuzz: @ Run fuzz tests for 30 seconds
fuzz:
	@export GOFLAGS=$(GOFLAGS); go test ./... -fuzz=Fuzz -fuzztime=30s

#clean: @ Clean up environment
clean:
	@rm -rf $(COVPROF) $(OUTDIR) dist/ completions/ manpages/ $(APP_NAME)
	@go clean -testcache

#update: @ Update dependency packages to latest versions
update:
	@go get -u ./...; go mod tidy

#release: @ Create and push a new tag
release:
	@bash -c 'read -p "New tag (current: $(CURRENTTAG)): " newtag && \
		echo "$$newtag" | grep -qE "^v[0-9]+\.[0-9]+\.[0-9]+$$" || { echo "Error: Tag must match vN.N.N"; exit 1; } && \
		echo -n "Create and push $$newtag? [y/N] " && read ans && [ "$${ans:-N}" = y ] && \
		echo $$newtag > ./version.txt && \
		git add -A && \
		git commit -a -s -m "Cut $$newtag release" && \
		git tag $$newtag && \
		git push origin $$newtag && \
		git push && \
		echo "Done."'

#ci: @ Run full CI pipeline locally
ci: static-check build test coverage-check
	@echo "Local CI pipeline passed."

#ci-full: @ Run full CI pipeline including coverage
ci-full: static-check build coverage-check
	@echo "Full CI pipeline passed."

#check: @ Run pre-commit checklist
check: static-check test build
	@echo "All pre-commit checks passed."

#deps-act: @ Install act for local CI
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin v$(ACT_VERSION); \
	}

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@act push --container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts

#renovate-bootstrap: @ Install nvm and npm for Renovate
renovate-bootstrap:
	@command -v node >/dev/null 2>&1 || { \
		echo "Installing nvm $(NVM_VERSION)..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install --lts; \
	}

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@npx --yes renovate --platform=local

.PHONY: help deps fmt fmtcheck spellcheck staticcheck critic sec vulncheck secrets \
	static-check lint build run test coverage coverage-check fuzz clean update release \
	ci ci-full check deps-act ci-run renovate-bootstrap renovate-validate
