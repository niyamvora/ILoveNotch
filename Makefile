# Developer entry points. CI runs these same targets.
CONFIGURATION ?= Debug
ARCH ?= $(shell uname -m)
DERIVED_DATA := .build/xcode
APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/OpenNotch.app

.PHONY: project build run test clean

project: ## Generate OpenNotch.xcodeproj from project.yml
	xcodegen generate --quiet

build: project ## Build the app; CONFIGURATION=Debug|Release
	xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -configuration $(CONFIGURATION) \
		-destination 'platform=macOS,arch=$(ARCH)' -derivedDataPath $(DERIVED_DATA) -quiet build

run: build ## Build and relaunch the app
	-pkill -x OpenNotch
	open $(APP)

test: ## Run unit and performance tests
	swift test -Xswiftc -warnings-as-errors

clean:
	rm -rf .build OpenNotch.xcodeproj
