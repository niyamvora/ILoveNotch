# Developer entry points. CI runs these same targets.
CONFIGURATION ?= Debug
ARCH ?= $(shell uname -m)
DERIVED_DATA := .build/xcode
APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/OpenNotch.app
SWIFT_SOURCES := App Sources Tests Package.swift
# The commit a build comes from, with "+" when the checkout has uncommitted changes (shown in the menu).
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null)$(shell git diff --quiet HEAD -- 2>/dev/null || echo +)
# Signs with your Apple Development certificate when you have one. macOS ties permissions (Calendar,
# Reminders, folders) to the signature, and an ad-hoc one changes with every build, so updates would
# ask again each time. Without a certificate (CI, most contributors) builds stay ad-hoc signed.
SIGNING_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $$2; exit}')

.PHONY: setup project build build-app-store run install update release app-store test lint format licenses check clean

setup: ## Install developer tools (Brewfile) and fetch submodules
	brew bundle
	git submodule update --init --recursive

project: ## Generate OpenNotch.xcodeproj from project.yml
	git submodule update --init --recursive
	xcodegen generate --quiet

build: project ## Build the app; CONFIGURATION=Debug|Release
	xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -configuration $(CONFIGURATION) \
		-destination 'platform=macOS,arch=$(ARCH)' -derivedDataPath $(DERIVED_DATA) \
		OPENNOTCH_COMMIT='$(COMMIT)' $(if $(SIGNING_IDENTITY),CODE_SIGN_IDENTITY='$(SIGNING_IDENTITY)') -quiet build

build-app-store: project ## Build the sandboxed App Store edition into its own folder
	xcodebuild -project OpenNotch.xcodeproj -scheme "OpenNotch App Store" -configuration $(CONFIGURATION) \
		-destination 'platform=macOS,arch=$(ARCH)' -derivedDataPath .build/xcode-appstore \
		$(if $(SIGNING_IDENTITY),CODE_SIGN_IDENTITY='$(SIGNING_IDENTITY)') -quiet build

run: build ## Build and relaunch the app
	-osascript -e 'quit app "OpenNotch"'
	open $(APP)

install: ## Build a Release app into /Applications and (re)launch it
	$(MAKE) build CONFIGURATION=Release
	@osascript -e 'quit app "OpenNotch"' >/dev/null 2>&1 || true
	@for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x OpenNotch >/dev/null || break; sleep 0.3; done; \
		pkill -x OpenNotch || true
	rm -rf /Applications/OpenNotch.app
	ditto $(DERIVED_DATA)/Build/Products/Release/OpenNotch.app /Applications/OpenNotch.app
	open /Applications/OpenNotch.app

update: ## Pull main when safe, rebuild, reinstall, relaunch (the app's "Update OpenNotch")
	scripts/update.sh

release: ## Sign, notarize, and draft a GitHub release: make release VERSION=0.3.0 (docs/releasing.md)
	scripts/release.sh $(VERSION)

app-store: ## Upload the App Store edition to App Store Connect: make app-store VERSION=0.3.0
	scripts/app-store.sh $(VERSION)

test: ## Run unit and performance tests
	swift test -Xswiftc -warnings-as-errors

lint: ## Fail on formatting drift (config: .swift-format)
	swift format lint --strict --recursive $(SWIFT_SOURCES)

format: ## Apply formatting in place
	swift format --in-place --recursive $(SWIFT_SOURCES)

licenses: ## SPDX headers and third-party notices
	scripts/check-licenses.sh

check: lint test build licenses ## Everything CI runs

clean:
	rm -rf .build OpenNotch.xcodeproj
