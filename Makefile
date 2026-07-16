.PHONY: run test test-integration analyze build-apk

run:
	flutter run

test:
	flutter test

test-integration:
	flutter test integration_test

analyze:
	flutter analyze

build-apk:
	flutter build apk --release
