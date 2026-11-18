# Pearl Player. Linux targets run on your Linux host (seconds, no Apple tooling).
# Apple targets need a Mac: a real one or a GitHub xcode-27 runner.
KIT := Packages/PearlKit
DESTINATION := platform=iOS Simulator,name=iPhone 17
PROJECT := PearlPlayer.xcodeproj

.PHONY: help linux-test linux-build format format-check lint generate build test-sim archive clean

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

# ---- Linux (your Linux host): PearlKit logic only, no SwiftUI, no VLCKit -------
linux-test: ## Run PearlKit unit tests on Linux
	swift test --package-path $(KIT)

linux-build: ## Build PearlKit on Linux
	swift build --package-path $(KIT)

format: ## Format all Swift sources in place
	swift format --in-place --recursive App AppTests $(KIT)/Sources $(KIT)/Tests

format-check: ## Fail if anything is unformatted
	swift format lint --recursive App AppTests $(KIT)/Sources $(KIT)/Tests

lint: ## SwiftLint
	swiftlint lint --quiet

# ---- macOS only ----------------------------------------------------------
generate: ## Generate $(PROJECT) from project.yml
	xcodegen generate

build: generate ## Build for the simulator
	xcodebuild -project $(PROJECT) -scheme PearlPlayer \
		-destination '$(DESTINATION)' \
		-derivedDataPath .build/DerivedData \
		CODE_SIGNING_ALLOWED=NO build

test-sim: generate ## Run the simulator test suite
	xcodebuild -project $(PROJECT) -scheme PearlPlayer \
		-destination '$(DESTINATION)' \
		-derivedDataPath .build/DerivedData \
		CODE_SIGNING_ALLOWED=NO test

archive: generate ## Release archive, unsigned
	xcodebuild -project $(PROJECT) -scheme PearlPlayer \
		-destination 'generic/platform=iOS' \
		-derivedDataPath .build/DerivedData \
		CODE_SIGNING_ALLOWED=NO \
		archive

clean:
	rm -rf .build $(PROJECT)
	swift package --package-path $(KIT) clean
