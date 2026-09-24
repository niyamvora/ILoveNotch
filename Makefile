# Developer entry points. CI runs these same targets.
CONFIGURATION ?= Debug
ARCH ?= $(shell uname -m)
DERIVED_DATA := .build/xcode
APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/OpenNotch.app
SWIFT_SOURCES := App Sources Tests Package.swift

.PHONY: setup project build run install test lint format licenses check clean

setup: ## Install developer tools (Brewfile) and fetch submodules
	brew bundle
	git submodule update --init --recursive

project: ## Generate OpenNotch.xcodeproj from project.yml
	git submodule update --init --recursive
	xcodegen generate --quiet

build: project ## Build the app; CONFIGURATION=Debug|Release
	xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -configuration $(CONFIGURATION) \
		-destination 'platform=macOS,arch=$(ARCH)' -derivedDataPath $(DERIVED_DATA) -quiet build

run: build ## Build and relaunch the app
	-osascript -e 'quit app "OpenNotch"'
	open $(APP)

install: ## Build a Release app into /Applications and launch it
	$(MAKE) build CONFIGURATION=Release
	-osascript -e 'quit app "OpenNotch"'
	rm -rf /Applications/OpenNotch.app
	ditto $(DERIVED_DATA)/Build/Products/Release/OpenNotch.app /Applications/OpenNotch.app
	open /Applications/OpenNotch.app

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
