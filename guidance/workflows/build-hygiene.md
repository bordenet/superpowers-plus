# Build Hygiene Standards

> **Priority**: CRITICAL - Apply to all projects with build steps  
> **Source**: RecipeArchive, genesis-tools Agents.md

## ⚠️ NEVER Modify Source In Place

Build processes should NEVER modify source files. Always output to dedicated directories.

```bash
# ❌ WRONG - modifying source
sed -i 's/version/1.0/' src/config.js

# ✅ CORRECT - build output separate from source
npm run build  # Outputs to dist/
cp src/config.template.js dist/config.js
sed 's/VERSION/1.0/' < src/config.template.js > dist/config.js
```

## Go Build Hygiene

**CRITICAL**: Always run `go build` after linting to verify compilation.

```bash
# Standard Go workflow
golangci-lint run ./...    # Step 1: Lint
go build ./...             # Step 2: ALWAYS compile after lint
go test ./...              # Step 3: Run tests
```

The linter may pass while the code doesn't compile. **`go build` is non-negotiable.**

## Compilation Validation

Before committing, verify the code compiles:

| Language | Compile Check |
|----------|---------------|
| Go | `go build ./...` |
| TypeScript | `tsc --noEmit` |
| Java | `mvn compile` or `gradle build` |
| Rust | `cargo check` |
| Dart | `dart analyze` or `flutter analyze` |

## Build Output Directories

Standard output directory conventions:

| Language/Framework | Build Output |
|-------------------|--------------|
| Node.js | `dist/` or `build/` |
| Go | `bin/` or project root |
| Python | `dist/` (for packages) |
| Flutter | `build/` |
| Rust | `target/` |

## Clean Builds

When builds behave unexpectedly, clean and rebuild:

```bash
# Node.js
rm -rf node_modules dist
npm ci  # Clean install
npm run build

# Go
go clean -cache
go build ./...

# Flutter
flutter clean
flutter pub get
flutter build

# Rust
cargo clean
cargo build
```

## CI Build Validation

Ensure CI validates:

1. **Lint passes** - No errors or warnings
2. **Build succeeds** - Code compiles without errors
3. **Tests pass** - All tests green
4. **Coverage met** - Minimum thresholds satisfied

```yaml
# Example CI steps
steps:
  - run: npm run lint
  - run: npm run build    # MUST come after lint
  - run: npm test
  - run: npm run coverage
```

## Build Artifacts

- Never commit build artifacts to git
- Use `.gitignore` to exclude build directories
- CI should build fresh, not reuse local builds
- Tag releases in git, store artifacts separately

## Dependency Lock Files

Always commit lock files for reproducible builds:

| Package Manager | Lock File |
|-----------------|-----------|
| npm | `package-lock.json` |
| yarn | `yarn.lock` |
| pnpm | `pnpm-lock.yaml` |
| Go | `go.sum` |
| Cargo | `Cargo.lock` |
| pip | `requirements.txt` (pinned) |
| Flutter | `pubspec.lock` |

