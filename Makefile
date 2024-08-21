projectname?=go-csv-struct

GOFMT_FILES = $(shell go list -f '{{.Dir}}' ./...)
CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (currnet tag - ${CURRENTTAG}): " newtag; echo $$newtag')

default: help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-11s\033[0m %s\n", $$1, $$2}'

.PHONY: fmtcheck
fmtcheck: ## format check
	@command -v goimports > /dev/null 2>&1 || (cd tools/ && go install golang.org/x/tools/cmd/goimports@latest)
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
	@command -v misspell > /dev/null 2>&1 || (cd tools/ && go install github.com/client9/misspell/cmd/misspell@latest)
	@misspell -locale="US" -error -source="text" **/*

.PHONY: staticcheck
staticcheck: ## static check
	@command -v staticcheck > /dev/null 2>&1 || (cd tools/ && go install honnef.co/go/tools/cmd/staticcheck@latest)
	@staticcheck -checks="all" -tests $(GOFMT_FILES)

.PHONY: build
build: ## build golang binary
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
	@command -v gofumpt > /dev/null 2>&1 || (cd tools/ && go install mvdan.cc/gofumpt@latest)
	@command -v gci > /dev/null 2>&1 || (cd tools/ && go install github.com/daixiang0/gci@latest)
	gofumpt -w .
	gci write .

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
