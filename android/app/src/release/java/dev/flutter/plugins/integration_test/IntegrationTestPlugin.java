package dev.flutter.plugins.integration_test;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Flutter 3.44 generates a release registrant entry for the dev-only
 * integration_test plugin, although its Android library is not part of the
 * release classpath. The release app does not run instrumentation tests, so
 * a no-op plugin keeps the generated registrant compilable without shipping
 * the test runner and its dependencies.
 */
public final class IntegrationTestPlugin implements FlutterPlugin {
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        // Integration tests are not initialized in release builds.
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        // Nothing to release.
    }
}
