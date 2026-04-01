//go:build tools

package tools

// https://github.com/golang/go/wiki/Modules#how-can-i-track-tool-dependencies-for-a-module

//go:generate go install mvdan.cc/gofumpt
//go:generate go install github.com/daixiang0/gci
//go:generate go install golang.org/x/tools/cmd/goimports
//go:generate go install github.com/go-critic/go-critic/cmd/gocritic

// nolint
import (
	// gci
	_ "github.com/daixiang0/gci"
	// gocritic
	_ "github.com/go-critic/go-critic/cmd/gocritic"
	// goimports
	_ "golang.org/x/tools/cmd/goimports"
	// gofumpt
	_ "mvdan.cc/gofumpt"
)
