---
allowed-tools: Bash(gh issue view*), Bash(gh api*), Bash(git checkout*), Bash(git branch*), Bash(git log*), Bash(git diff*), Bash(git status*), Bash(make *), Read, Write, Edit, Glob, Grep, Agent
---

Analyze GitHub issue #$ARGUMENTS and implement the proposed changes.

## Phase 1: Research & Analysis

1. Run `gh issue view $ARGUMENTS --json number,title,state,body,labels,comments,assignees` to fetch the full issue details
2. Read the issue title, description, labels, and all comments to understand the requirements
3. Explore the codebase to identify all files relevant to the issue
4. Analyze the impact: what needs to change, what tests are affected, what risks exist

## Phase 2: Present Plan & Get Approval

1. Present a concise summary of the analysis to the user covering:
   - **Issue Summary**: Title, link, key requirements
   - **Affected Files**: List of files that need changes with explanations
   - **Proposed Changes**: Detailed description of each change
   - **Test Strategy**: What tests to add/modify
   - **Risks & Considerations**: Edge cases, breaking changes, backwards compatibility
2. **Ask the user to approve or reject the plan before proceeding**
3. If rejected, stop and ask for feedback

## Phase 3: Implementation (only after user approval)

1. Create and switch to branch `issue-$ARGUMENTS` from the current branch:
   ```
   git checkout -b issue-$ARGUMENTS
   ```
2. Implement the changes following the approved plan
3. Follow project conventions:
   - Idiomatic Go patterns
   - Table-driven tests with testify/assert
   - Proper error handling
   - Input validation

## Phase 4: Verification

Run each step sequentially and fix any failures before proceeding to the next:

1. `go vet ./...` — Go vet
2. `make fmtcheck` — Format check
3. `make staticcheck` — Static analysis
4. `make sec` — Security scan
5. `make critic` — Go critic
6. `make test` — Unit tests with coverage
7. `make build` — Compile

If any step fails, fix the issue and re-run that step before continuing. After all steps pass, report the final status to the user.
