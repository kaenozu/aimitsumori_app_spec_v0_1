.PHONY: run test test-integration analyze icons splash build-apk build-release-apk audit-release-apk release-prep

DEVICE ?= windows

run:
	flutter run

format:
	dart format lib test integration_test

test:
	flutter test

test-integration:
	flutter test -d $(DEVICE) integration_test

analyze:
	flutter analyze

build-debug:
	flutter build apk --debug

build-aab:
	@test -f android/key.properties || (echo "android/key.properties が必要です" && exit 1)
	@test -n "$(ADMOB_ANDROID_APP_ID)" || (echo "ADMOB_ANDROID_APP_ID が必要です" && exit 1)
	@test -n "$(ADMOB_ANDROID_BANNER_ID)" || (echo "ADMOB_ANDROID_BANNER_ID が必要です" && exit 1)
	@test -n "$(ADMOB_ANDROID_REWARDED_ID)" || (echo "ADMOB_ANDROID_REWARDED_ID が必要です" && exit 1)
	@test -n "$(PURCHASE_VERIFICATION_URL)" || (echo "PURCHASE_VERIFICATION_URL が必要です" && exit 1)
	ADMOB_ANDROID_APP_ID="$(ADMOB_ANDROID_APP_ID)" flutter build appbundle --release \
		--dart-define=ADMOB_ANDROID_BANNER_ID="$(ADMOB_ANDROID_BANNER_ID)" \
		--dart-define=ADMOB_ANDROID_REWARDED_ID="$(ADMOB_ANDROID_REWARDED_ID)" \
		--dart-define=PURCHASE_VERIFICATION_URL="$(PURCHASE_VERIFICATION_URL)"

build-apk:
	flutter build apk --debug

build-release-apk:
	powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_android_release.ps1 -Artifact apk

audit-release-apk:
	powershell -NoProfile -ExecutionPolicy Bypass -File tool/audit_android_release.ps1

release-prep: icons splash analyze test build-release-apk
