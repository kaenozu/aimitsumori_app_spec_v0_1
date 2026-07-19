.PHONY: run test test-integration analyze icons splash build-apk build-release-apk audit-release-apk release-prep

DEVICE ?= windows

run:
	flutter run

test:
	flutter test

test-integration:
	flutter test -d $(DEVICE) integration_test

analyze:
	flutter analyze

icons:
	dart run flutter_launcher_icons

splash:
	dart run flutter_native_splash:create

build-apk:
	flutter build apk --debug

build-release-apk:
	powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_android_release.ps1 -Artifact apk

audit-release-apk:
	powershell -NoProfile -ExecutionPolicy Bypass -File tool/audit_android_release.ps1

release-prep: icons splash analyze test build-release-apk
