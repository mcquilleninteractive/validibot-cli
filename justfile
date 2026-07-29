# Validibot CLI development commands

# Default recipe - show available commands
default:
    @just --list

# Run tests
test:
    uv run --extra dev pytest

# Run tests with coverage
test-cov:
    uv run --extra dev pytest --cov=validibot_cli

# Lint and format
lint:
    uv run --extra dev ruff check .
    uv run --extra dev ruff format --check .

# Format code
fmt:
    uv run --extra dev ruff format .
    uv run --extra dev ruff check --fix .

# Type check
typecheck:
    uv run --extra dev mypy src/

# Run all checks (lint, typecheck, test)
check: lint typecheck test

# Run the CLI locally
run *ARGS:
    uv run validibot {{ARGS}}

# Release a new version (signed tag + GitHub release → verified PyPI publish)
# Usage: just release 0.3.2
release VERSION:
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ ! "{{VERSION}}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Version must be in format X.Y.Z (e.g., 0.3.2)"
        exit 1
    fi

    if [[ -n $(git status --porcelain) ]]; then
        echo "Error: You have uncommitted changes. Commit or stash them first."
        exit 1
    fi

    BRANCH="$(git branch --show-current)"
    if [[ "$BRANCH" != "main" ]]; then
        echo "Error: Releases must be created from main, not '$BRANCH'."
        exit 1
    fi

    git fetch origin main
    LOCAL_COMMIT="$(git rev-parse HEAD)"
    REMOTE_COMMIT="$(git rev-parse origin/main)"
    if [[ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
        echo "Error: Local main must exactly match origin/main."
        exit 1
    fi

    TOML_VERSION="$(python3 -c \
        'import pathlib, tomllib; print(tomllib.loads(pathlib.Path("pyproject.toml").read_text())["project"]["version"])')"
    if [[ "$TOML_VERSION" != "{{VERSION}}" ]]; then
        echo "Error: Version in pyproject.toml ($TOML_VERSION) doesn't match {{VERSION}}"
        exit 1
    fi

    TAG="v{{VERSION}}"
    if git rev-parse "$TAG" >/dev/null 2>&1; then
        echo "Error: Tag $TAG already exists."
        exit 1
    fi

    echo "Running the full release gate..."
    just check
    uv lock --check
    RELEASE_CHECK_DIR="$(mktemp -d)"
    trap 'rm -rf "$RELEASE_CHECK_DIR"' EXIT
    uv build --no-sources --out-dir "$RELEASE_CHECK_DIR"
    uvx --from twine==7.0.0 twine check --strict "$RELEASE_CHECK_DIR"/*

    echo "Creating and verifying signed tag $TAG..."
    git tag -s -m "Release $TAG" "$TAG"
    git verify-tag "$TAG"
    git push origin "$TAG"

    gh release create "$TAG" \
        --verify-tag \
        --title "$TAG" \
        --generate-notes

    echo ""
    echo "Release $TAG created from signed tag $LOCAL_COMMIT."
    echo "GitHub Actions will verify it again, attest it, and publish to PyPI."
    echo "Monitor: gh run list --limit 3"
