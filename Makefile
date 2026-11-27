SCHEME      := Wingmate
PROJECT     := Wingmate.xcodeproj
DERIVED     := build/DerivedData
DESTINATION := platform=macOS

.PHONY: bootstrap generate open build test lint format release install clean

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

release: generate ## Local Release build + zip/dmg into dist/
	./scripts/build-release.sh

install: ## Install latest GitHub release to /Applications (or: make install TAG=v0.1.0)
	./scripts/install.sh $(TAG)

clean:
	rm -rf build dist $(PROJECT)
