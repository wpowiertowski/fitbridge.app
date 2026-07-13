.PHONY: xcode test clean prune-branches

xcode:
	xcodegen generate
	open HealthLoom.xcodeproj

XCODE_BETA := /Applications/Xcode-beta.app/Contents/Developer

test:
	@for pkg in CoreModel Secrets GoogleHealthClient SyncKit CoachKit; do \
		echo "==> swift test ($$pkg)"; \
		(cd Packages/$$pkg && swift test -Xswiftc -warnings-as-errors) || exit 1; \
	done
	@test -d "$(XCODE_BETA)" || { \
		echo "error: $(XCODE_BETA) not found -- the app target needs the iOS 27 SDK from the Xcode 27 beta, and GitHub's macos-26 runner doesn't ship it yet, so this is the only real gate for it. Install the Xcode 27 beta." >&2; \
		exit 1; \
	}
	xcodegen generate
	@udid=$$(DEVELOPER_DIR="$(XCODE_BETA)" xcrun simctl list devices available \
		| awk '/-- iOS 27\.0 --/{flag=1; next} /^--/{flag=0} flag' \
		| grep -E 'iPhone' \
		| grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' \
		| head -n1); \
	if [ -z "$$udid" ]; then \
		echo "error: no available iPhone simulator on the iOS 27.0 runtime -- run 'DEVELOPER_DIR=$(XCODE_BETA) xcodebuild -downloadPlatform iOS' to install it. (project.yml's deploymentTarget is iOS 27.0; other installed runtimes won't satisfy it.)" >&2; \
		exit 1; \
	fi; \
	echo "==> xcodebuild build test (destination iOS Simulator $$udid)"; \
	DEVELOPER_DIR="$(XCODE_BETA)" xcodebuild build test \
		-project HealthLoom.xcodeproj \
		-scheme HealthLoom \
		-destination "platform=iOS Simulator,id=$$udid" \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
		GCC_TREAT_WARNINGS_AS_ERRORS=YES

clean:
	rm -rf HealthLoom.xcodeproj
	rm -rf ~/Library/Developer/Xcode/DerivedData/HealthLoom-*
	@for pkg in CoreModel Secrets GoogleHealthClient SyncKit CoachKit; do \
		(cd Packages/$$pkg && swift package clean); \
	done
	xcrun simctl uninstall booted com.healthloom.app 2>/dev/null || true

prune-branches:
	@git fetch --prune origin
	@current=$$(git branch --show-current); \
	merged=$$(gh pr list --state merged --limit 200 --json headRefName --jq '.[].headRefName' | sort -u); \
	deleted=0; \
	for branch in $$(git for-each-ref --format='%(refname:short)' refs/heads/); do \
		case "$$branch" in main|master) continue ;; esac; \
		if [ "$$branch" = "$$current" ]; then continue; fi; \
		if printf '%s\n' "$$merged" | grep -qx "$$branch"; then \
			git branch -D "$$branch"; \
			deleted=$$((deleted + 1)); \
		fi; \
	done; \
	echo "Pruned $$deleted merged branch(es)."
