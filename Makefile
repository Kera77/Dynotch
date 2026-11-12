SCHEME      := Dynotch
PROJECT     := Dynotch.xcodeproj
DERIVED     := build/DerivedData
DESTINATION := platform=macOS

.PHONY: bootstrap generate open build test lint format release clean

bootstrap: ## Install dev tools
	brew bundle

generate: ## Generate Xcode project from project.yml
	xcodegen generate

open: generate ## Generate and open in Xcode
	open $(PROJECT)

build: generate ## Debug build
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO build

test: generate ## Run unit tests
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO test

lint: ## Lint Swift sources
	swiftlint --strict

format: ## Autocorrect lint issues
	swiftlint --fix

release: generate ## Local unsigned Release build + zip into dist/
	./scripts/build-release.sh

clean:
	rm -rf build dist $(PROJECT)
