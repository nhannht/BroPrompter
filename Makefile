# BroPrompter developer tasks. Source of truth for the Airbnb lint/format
# workflow. See CLAUDE.md "Linting and formatting" and BROP-26.

EXCLUDES := --exclude build --exclude BroPrompter.xcodeproj

.PHONY: format lint hooks generate build

## format: Autofix all Swift sources to the Airbnb Swift Style Guide.
format:
	swift package --allow-writing-to-package-directory format $(EXCLUDES)

## lint: Check formatting + lint without modifying files. Non-zero exit on any violation.
lint:
	swift package --allow-writing-to-package-directory format --lint $(EXCLUDES)

## hooks: Point git at the versioned hooks in .githooks (run once per clone).
hooks:
	git config core.hooksPath .githooks

## generate: Regenerate BroPrompter.xcodeproj from project.yml.
generate:
	xcodegen generate

## build: Build the app (Debug, ad-hoc signing).
build:
	xcodebuild -scheme BroPrompter -destination 'platform=macOS' -configuration Debug build CODE_SIGN_IDENTITY="-"
