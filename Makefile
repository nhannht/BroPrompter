# BroPrompter developer tasks. Source of truth for the Airbnb lint/format
# workflow. See CLAUDE.md "Linting and formatting" and BROP-26.

EXCLUDES := --exclude build --exclude BroPrompter.xcodeproj

# Debug / screenshot tooling (all output under the gitignored build/).
APP_DERIVED := build/DerivedData
APP_PATH := $(APP_DERIVED)/Build/Products/Debug/BroPrompter.app
WINID := build/winid
SHOTS := build/screenshots

.PHONY: format lint hooks generate build run screenshot test

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

## test: Run headless unit/integration tests (BROP-29). Run `make generate` after any project.yml change.
test:
	xcodebuild test -scheme BroPrompter -destination 'platform=macOS' -configuration Debug -derivedDataPath $(APP_DERIVED) -only-testing:BroPrompterTests CODE_SIGN_IDENTITY="-"

## run: Build (Debug, ad-hoc) and launch the app for manual/visual debugging.
run:
	xcodebuild -scheme BroPrompter -destination 'platform=macOS' -configuration Debug -derivedDataPath $(APP_DERIVED) build CODE_SIGN_IDENTITY="-"
	open $(APP_PATH)

## screenshot: Capture the running BroPrompter window to build/screenshots (no cursor/focus change). Needs Screen Recording granted to the terminal once.
screenshot: $(WINID)
	@mkdir -p $(SHOTS)
	@wid=$$($(WINID) BroPrompter) && screencapture -x -o -l $$wid $(SHOTS)/broprompter.png && echo "wrote $(SHOTS)/broprompter.png (window $$wid)"

$(WINID): tools/winid.swift
	@mkdir -p build
	swiftc -O -o $(WINID) tools/winid.swift
