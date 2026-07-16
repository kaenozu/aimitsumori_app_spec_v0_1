.PHONY: run test test-integration analyze icons splash build-apk release-prep

run:
	flutter run

test:
	flutter test

test-integration:
	flutter test integration_test

analyze:
	flutter analyze

icons:
	dart run flutter_launcher_icons

splash:
	dart run flutter_native_splash:create

build-apk:
	flutter build apk --release

release-prep: icons splash analyze test build-apk
