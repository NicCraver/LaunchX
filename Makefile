# LaunchX Tagging & Release Makefile

# Get the current latest tag, default to 0.0.0 if none exists
CURRENT_VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")

.PHONY: help tag push release clean-tags

help:
	@echo "LaunchX Management Commands:"
	@echo "  make tag v=1.0.0     - Create a local annotated tag (v1.0.0)"
	@echo "  make push            - Push all local tags to origin"
	@echo "  make release v=1.0.0 - Create tag and push to origin in one step"
	@echo "  make clean-tags      - Delete all local tags"
	@echo ""
	@echo "Current Latest Tag: v$(CURRENT_VERSION)"

## Create a new local tag
tag:
	@if [ -z "$(v)" ]; then \
		echo "Error: Version (v) is required. Example: make tag v=1.2.3"; \
		exit 1; \
	fi
	@if git rev-parse "v$(v)" >/dev/null 2>&1; then \
		echo "Error: Tag v$(v) already exists."; \
		exit 1; \
	fi
	@echo "Creating tag v$(v)..."
	git tag -a v$(v) -m "Release version $(v)"
	@echo "Tag v$(v) created."

## Push tags to remote
push:
	@echo "Pushing tags to origin..."
	git push origin --tags

## Release: Tag and Push
release:
	@if [ -z "$(v)" ]; then \
		echo "Error: Version (v) is required. Example: make release v=1.2.3"; \
		exit 1; \
	fi
	@$(MAKE) tag v=$(v)
	@$(MAKE) push
	@echo "Successfully released v$(v)"

## Clean local tags (useful for fixing mistakes before pushing)
clean-tags:
	@echo "This will delete ALL local tags. Are you sure? [y/N]" && read ans && [ $${ans:-N} = y ]
	@git tag -l | xargs git tag -d
	@echo "Local tags cleaned."
