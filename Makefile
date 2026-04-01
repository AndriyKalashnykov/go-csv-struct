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
GVM_SHA              := dd652539fa4b771840846f8319fad303c7d0a8d2 # v1.0.22
NVM_VERSION          := 0.40.4

# === Go Version Management ===
GO_VERSIONS := $(shell find . -name 'go.mod' -exec grep -oP '^go \K[0-9.]+' {} \; | sort -uV)
GO_VERSION  := $(shell grep -oP '^go \K[0-9.]+' go.mod)

# gvm detection — gvm is a shell function, not a binary; check for scripts directory
HAS_GVM := $(shell [ -s "$$HOME/.gvm/scripts/gvm" ] && echo true || echo false)

# Helper: run a command under the correct Go version via gvm (or directly if gvm absent)
# In CI, actions/setup-go provides Go directly — gvm is not needed.
# Locally, gvm sets GOROOT/GOPATH/PATH in a subshell.
define go-exec
$(if $(filter true,$(HAS_GVM)),bash -c '. $$HOME/.gvm/scripts/gvm && gvm use go$(GO_VERSION) >/dev/null 2>&1 && $(1)',bash -c '$(1)')
endef

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
	@# Install gvm if not present (local development only, CI uses actions/setup-go)
	@if [ -z "$$CI" ] && [ ! -s "$$HOME/.gvm/scripts/gvm" ]; then \
		echo "Installing gvm (Go Version Manager)..."; \
		curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/$(GVM_SHA)/binscripts/gvm-installer | bash -s $(GVM_SHA); \
		echo ""; \
		echo "gvm installed. Please restart your shell or run:"; \
		echo "  source $$HOME/.gvm/scripts/gvm"; \
		echo "Then re-run 'make deps' to install Go $(GO_VERSION) via gvm."; \
		exit 0; \
	fi
	@# Install required Go versions via gvm
	@if [ "$(HAS_GVM)" = "true" ]; then \
		for v in $(GO_VERSIONS); do \
			bash -c '. $$HOME/.gvm/scripts/gvm && gvm list' 2>/dev/null | grep -q "go$$v" || { \
				echo "Installing Go $$v via gvm..."; \
				bash -c '. $$HOME/.gvm/scripts/gvm && gvm install go'"$$v"' -B'; \
			}; \
		done; \
	else \
		command -v go >/dev/null 2>&1 || { echo "Error: Go required. Install gvm from https://github.com/moovweb/gvm or Go from https://go.dev/dl/"; exit 1; }; \
	fi
	@$(call go-exec,command -v gocritic) >/dev/null 2>&1 || { echo "Installing gocritic..."; $(call go-exec,go install github.com/go-critic/go-critic/cmd/gocritic@$(GOCRITIC_VERSION)); }
	@$(call go-exec,command -v gosec) >/dev/null 2>&1 || { echo "Installing gosec..."; $(call go-exec,go install github.com/securego/gosec/v2/cmd/gosec@$(GOSEC_VERSION)); }
	@$(call go-exec,command -v misspell) >/dev/null 2>&1 || { echo "Installing misspell..."; $(call go-exec,go install github.com/client9/misspell/cmd/misspell@$(MISSPELL_VERSION)); }
	@$(call go-exec,command -v staticcheck) >/dev/null 2>&1 || { echo "Installing staticcheck..."; $(call go-exec,go install honnef.co/go/tools/cmd/staticcheck@$(STATICCHECK_VERSION)); }
	@$(call go-exec,command -v gofumpt) >/dev/null 2>&1 || { echo "Installing gofumpt..."; $(call go-exec,go install mvdan.cc/gofumpt@$(GOFUMPT_VERSION)); }
	@$(call go-exec,command -v gci) >/dev/null 2>&1 || { echo "Installing gci..."; $(call go-exec,go install github.com/daixiang0/gci@$(GCI_VERSION)); }
	@$(call go-exec,command -v goimports) >/dev/null 2>&1 || { echo "Installing goimports..."; $(call go-exec,go install golang.org/x/tools/cmd/goimports@$(GOIMPORTS_VERSION)); }
	@$(call go-exec,command -v govulncheck) >/dev/null 2>&1 || { echo "Installing govulncheck..."; $(call go-exec,go install golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION)); }
	@$(call go-exec,command -v gitleaks) >/dev/null 2>&1 || { echo "Installing gitleaks..."; $(call go-exec,go install github.com/zricethezav/gitleaks/v8@$(GITLEAKS_VERSION)); }

#deps-check: @ Show required Go versions and gvm status
deps-check:
	@echo "Go versions required: $(GO_VERSIONS)"
	@echo "Primary Go version:   $(GO_VERSION)"
	@if [ -s "$$HOME/.gvm/scripts/gvm" ]; then \
		bash -c '. $$HOME/.gvm/scripts/gvm && gvm list'; \
	else \
		echo "gvm not installed — install from https://github.com/moovweb/gvm"; \
	fi

#fmt: @ Format Go files (gofumpt + gci)
fmt: deps
	@gofumpt -w .
	@gci write .

#format: @ Alias for fmt
format: fmt

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
	@$(call go-exec,go build ./...)

#run: @ Run example application
run: build
	@$(call go-exec,go run ./example/...)

#test: @ Run tests with coverage
test: deps
	@$(call go-exec,go clean -testcache)
	@$(call go-exec,go test --cover -parallel=1 -v -coverprofile=$(COVPROF) $(PKGS))
	@$(call go-exec,go tool cover -func=$(COVPROF) | sort -rnk3)

#coverage: @ Run tests with HTML coverage report
coverage: deps
	@$(call go-exec,go clean -testcache)
	@mkdir -p $(OUTDIR)
	@$(call go-exec,go test --cover -parallel=1 -v -coverprofile=$(COVPROF) -covermode=atomic $(PKGS))
	@$(call go-exec,go tool cover -func=$(COVPROF))
	@$(call go-exec,go tool cover -html=$(COVPROF) -o $(OUTDIR)/coverage.html)
	@echo "Coverage report: $(OUTDIR)/coverage.html"

#coverage-check: @ Verify coverage meets 80% threshold
coverage-check: coverage
	@TOTAL=$$($(call go-exec,go tool cover -func=$(COVPROF)) | grep total | awk '{print $$3}' | tr -d '%'); \
	echo "Coverage: $${TOTAL}%"; \
	if awk "BEGIN {exit !($${TOTAL} < 80)}"; then \
		echo "FAIL: Coverage $${TOTAL}% is below 80% threshold"; exit 1; \
	else \
		echo "PASS: Coverage meets 80% threshold"; \
	fi

#fuzz: @ Run fuzz tests for 30 seconds
fuzz: deps
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) && go test ./... -fuzz=Fuzz -fuzztime=30s)

#clean: @ Clean up environment
clean:
	@rm -rf $(COVPROF) $(OUTDIR) dist/ completions/ manpages/ $(APP_NAME)
	@$(call go-exec,go clean -testcache)

#update: @ Update dependency packages to latest versions
update: deps
	@$(call go-exec,go get -u ./... && go mod tidy)

#deps-prune: @ Remove unused Go dependencies
deps-prune: deps
	@$(call go-exec,go mod tidy)

#deps-prune-check: @ Verify no prunable dependencies (CI gate)
deps-prune-check: deps
	@$(call go-exec,go mod tidy)
	@if ! git diff --exit-code go.mod go.sum >/dev/null 2>&1; then \
		echo "ERROR: go.mod/go.sum not tidy. Run 'make deps-prune'."; \
		git checkout go.mod go.sum; \
		exit 1; \
	fi
	@echo "No prunable dependencies found."

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
ci: static-check test coverage-check build
	@echo "Local CI pipeline passed."

#ci-full: @ Run full CI pipeline including coverage
ci-full: static-check coverage-check build
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

.PHONY: help deps deps-check deps-act deps-prune deps-prune-check \
	fmt format fmtcheck spellcheck staticcheck critic sec vulncheck secrets \
	static-check lint build run test coverage coverage-check fuzz \
	clean update release ci ci-full check ci-run \
	renovate-bootstrap renovate-validate
