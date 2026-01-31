# Go Coding Conventions

> **Priority**: HIGH - Apply to all Go projects  
> **Source**: pr-faq-validator, genesis Agents.md

## Code Quality Requirements

- **Linting**: golangci-lint (all enabled checks)
- **Coverage**: ≥80% minimum, 85%+ target
- **Function length**: ≤50 lines
- **File length**: ≤400 lines

## Error Handling Pattern

Always use error wrapping with context:

```go
// ✅ Correct - wrap with context
if err != nil {
    return fmt.Errorf("failed to open config file %s: %w", path, err)
}

// ❌ Wrong - bare error return
if err != nil {
    return err
}

// ❌ Wrong - losing the original error
if err != nil {
    return fmt.Errorf("config error: %v", err)  // Use %w, not %v
}
```

## Package Structure

```
project/
├── cmd/           # Entry points
├── internal/      # Private packages
├── pkg/           # Public packages
├── go.mod
└── go.sum
```

## Testing Patterns

```go
// Table-driven tests preferred
func TestFunction(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    string
        wantErr bool
    }{
        {"valid input", "foo", "bar", false},
        {"empty input", "", "", true},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Function(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if got != tt.want {
                t.Errorf("got = %v, want %v", got, tt.want)
            }
        })
    }
}
```

## Commands

```bash
# Lint
golangci-lint run ./...

# Test with coverage
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out

# Security scan
govulncheck ./...
```

