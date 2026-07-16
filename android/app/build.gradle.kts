import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val productionAdMobAppId = project.findProperty("ADMOB_ANDROID_APP_ID") as String?

if (releaseRequested) {
    require(keystorePropertiesFile.exists()) {
        "Release signing is not configured. Create android/key.properties."
    }
    require(!productionAdMobAppId.isNullOrBlank()) {
        "ADMOB_ANDROID_APP_ID must be provided for release builds."
    }
}

android {
    namespace = "com.kaenozu.aimitsumori_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kaenozu.aimitsumori_app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            manifestPlaceholders["adMobApplicationId"] =
                "ca-app-pub-3940256099942544~3347511713"
        }
        getByName("release") {
            manifestPlaceholders["adMobApplicationId"] =
                productionAdMobAppId ?: "missing-admob-application-id"
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
}

flutter {
    source = "../.."
}
