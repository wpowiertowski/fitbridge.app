.PHONY: xcode test clean prune-branches

xcode:
	xcodegen generate
	open HealthLoom.xcodeproj

test:
	@for pkg in CoreModel Secrets GoogleHealthClient SyncKit CoachKit; do \
		echo "==> swift test ($$pkg)"; \
		(cd Packages/$$pkg && swift test -Xswiftc -warnings-as-errors) || exit 1; \
	done
	xcodegen generate
	xcodebuild build -project HealthLoom.xcodeproj -scheme HealthLoom -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO

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
