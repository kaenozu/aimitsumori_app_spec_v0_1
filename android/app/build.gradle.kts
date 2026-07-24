import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

val adMobAppId = providers.gradleProperty("admobAppId")
    .orElse(providers.environmentVariable("ADMOB_APP_ID"))
    .orNull
val adMobBannerId = providers.environmentVariable("ADMOB_ANDROID_BANNER_ID").orNull
val adMobRewardedId = providers.environmentVariable("ADMOB_ANDROID_REWARDED_ID").orNull
val removeAdsProductId = providers.environmentVariable("REMOVE_ADS_PRODUCT_ID").orNull
val purchaseVerificationUrl = providers.environmentVariable("PURCHASE_VERIFICATION_URL").orNull

if (releaseTaskRequested) {
    require(keystorePropertiesFile.isFile) {
        "android/key.properties is required for release builds."
    }
    val storeFileProperty = keystoreProperties.getProperty("storeFile")
    val keyAliasProperty = keystoreProperties.getProperty("keyAlias")
    require(!storeFileProperty.isNullOrBlank()) {
        "key.properties must define storeFile."
    }
    require(!keyAliasProperty.isNullOrBlank()) {
        "key.properties must define keyAlias."
    }
    require(!keystoreProperties.getProperty("storePassword").isNullOrBlank()) {
        "key.properties must define storePassword."
    }
    require(!keystoreProperties.getProperty("keyPassword").isNullOrBlank()) {
        "key.properties must define keyPassword."
    }
    val resolvedStoreFile = rootProject.file(storeFileProperty)
    require(resolvedStoreFile.isFile) {
        "storeFile must point to an existing release keystore."
    }
    require(!resolvedStoreFile.name.equals("debug.keystore", ignoreCase = true)) {
        "debug.keystore cannot be used for release builds."
    }
    require(keyAliasProperty != "androiddebugkey") {
        "androiddebugkey cannot be used for release builds."
    }

    require(!adMobAppId.isNullOrBlank()) {
        "ADMOB_APP_ID is required for release builds."
    }
    require(!adMobBannerId.isNullOrBlank()) {
        "ADMOB_ANDROID_BANNER_ID is required for release builds."
    }
    require(!adMobRewardedId.isNullOrBlank()) {
        "ADMOB_ANDROID_REWARDED_ID is required for release builds."
    }
    require(!removeAdsProductId.isNullOrBlank()) {
        "REMOVE_ADS_PRODUCT_ID is required for release builds."
    }
    require(!purchaseVerificationUrl.isNullOrBlank()) {
        "PURCHASE_VERIFICATION_URL is required for release builds."
    }
    require(
        Regex("https://[^\\s]+", RegexOption.IGNORE_CASE).matches(purchaseVerificationUrl),
    ) {
        "PURCHASE_VERIFICATION_URL must be an HTTPS URL."
    }
    require(Regex("ca-app-pub-\\d{16}~\\d{10}").matches(adMobAppId)) {
        "ADMOB_APP_ID must be a valid AdMob application ID."
    }
    require(Regex("ca-app-pub-\\d{16}/\\d{10}").matches(adMobBannerId)) {
        "ADMOB_ANDROID_BANNER_ID must be a valid AdMob ad unit ID."
    }
    require(Regex("ca-app-pub-\\d{16}/\\d{10}").matches(adMobRewardedId)) {
        "ADMOB_ANDROID_REWARDED_ID must be a valid AdMob ad unit ID."
    }
    require(Regex("[A-Za-z0-9._-]{1,100}").matches(removeAdsProductId)) {
        "REMOVE_ADS_PRODUCT_ID must be a valid Google Play product ID."
    }

    val googleTestIds = setOf(
        "ca-app-pub-3940256099942544~3347511713",
        "ca-app-pub-3940256099942544/6300978111",
        "ca-app-pub-3940256099942544/5224354917",
    )
    require(adMobAppId !in googleTestIds) {
        "ADMOB_APP_ID must not use Google's test application ID in release builds."
    }
    require(adMobBannerId !in googleTestIds) {
        "ADMOB_ANDROID_BANNER_ID must not use Google's test ad unit ID in release builds."
    }
    require(adMobRewardedId !in googleTestIds) {
        "ADMOB_ANDROID_REWARDED_ID must not use Google's test ad unit ID in release builds."
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
        manifestPlaceholders["admobAppId"] =
            adMobAppId ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.isFile) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
