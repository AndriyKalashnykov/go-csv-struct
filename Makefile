projectname?=go-csv-struct

GOFMT_FILES = $(shell go list -f '{{.Dir}}' ./...)
CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (currnet tag - ${CURRENTTAG}): " newtag; echo $$newtag')

default: help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-11s\033[0m %s\n", $$1, $$2}'

deps: ## Download and install dependencies
	go install -v github.com/go-critic/go-critic/cmd/gocritic@latest
	go install github.com/securego/gosec/v2/cmd/gosec@latest
	@command -v misspell > /dev/null 2>&1 || (go install github.com/client9/misspell/cmd/misspell@latest)
	@command -v staticcheck > /dev/null 2>&1 || (go install honnef.co/go/tools/cmd/staticcheck@latest)
	@command -v gofumpt > /dev/null 2>&1 || (go install mvdan.cc/gofumpt@latest)
	@command -v gci > /dev/null 2>&1 || (go install github.com/daixiang0/gci@latest)
	@command -v goimports > /dev/null 2>&1 || (go install golang.org/x/tools/cmd/goimports@latest)
	curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $$(go env GOPATH)/bin

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
	@misspell -locale="US" -error -source="text" **/*

.PHONY: staticchec
staticcheck: ## static check

	@staticcheck -checks="all" -tests $(GOFMT_FILES)

.PHONY: build
build: fmt ## build golang binary
	@go build -ldflags "-X main.version=$(shell git describe --abbrev=0 --tags)" -o $(projectname)

.PHONY: test
test: clean ## display test coverage
	go test --cover -parallel=1 -v -coverprofile=coverage.out ./...
	go tool cover -func=coverage.out | sort -rnk3
		
.PHONY: clean
clean: ## clean up environment
	@rm -rf coverage.out dist/ completions/ manpages/ $(projectname)

.PHONY: fmt
fmt: ## format go files
	@gofumpt -w .
	@gci write .

.PHONY: update
update: ## update dependency packages to latest versions
	@go get -u ./...; go mod tidy

.PHONY: release
release: ## create and push a new tag
	$(eval NT=$(NEWTAG))
	@echo -n "Are you sure to create and push ${NT} tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo ${NT} > ./version.txt
	@git add -A
	@git commit -a -s -m "Cut ${NT} release"
	@git tag ${NT}
	@git push origin ${NT}
	@git push
	@echo "Done."

critic:
	gocritic check -enableAll ./...

sec:
	gosec ./...
